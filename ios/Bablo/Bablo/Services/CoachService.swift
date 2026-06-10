//
//  CoachService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 3
//  Handles AI Coach Insights via Supabase Edge Functions
//

import Foundation
import Supabase

// MARK: - Data Models

struct CoachInsight: Codable, Equatable {
    let badge: String
    let headline: String
    let nudgeText: String
    let actionLabel: String
    let alternativeTip: String

    enum CodingKeys: String, CodingKey {
        case badge
        case headline
        case nudgeText = "nudge_text"
        case actionLabel = "action_label"
        case alternativeTip = "alternative_tip"
    }
}

enum CoachMissionType: String, Codable, Equatable {
    case coffeeCap   = "coffee_cap"
    /// Keep a chosen flexible category under a daily cap for N days.
    case categoryCap = "category_cap"
    /// N days with zero discretionary spend.
    case noSpend     = "no_spend"
}

enum CoachMissionStatus: String, Codable, Equatable {
    case active
    case completed
    case dismissed
    case cancelled
}

struct CoachMission: Codable, Identifiable, Equatable {
    let id: Int
    let userId: String
    let missionType: CoachMissionType
    let title: String
    let icon: String
    let targetGoalId: Int?
    let goalName: String?
    let startDate: String
    let endDate: String
    let projectedSavings: Double
    let actualSavings: Double
    let status: CoachMissionStatus
    let completedDays: Int
    let totalDays: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case missionType = "mission_type"
        case title
        case icon
        case targetGoalId = "target_goal_id"
        case goalName = "goal_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case projectedSavings = "projected_savings"
        case actualSavings = "actual_savings"
        case status
        case completedDays = "completed_days"
        case totalDays = "total_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isActive: Bool { status == .active }
    var isReadyToComplete: Bool { isActive && completedDays >= totalDays }
    var progressFraction: Double {
        guard totalDays > 0 else { return 0 }
        return min(1, max(0, Double(completedDays) / Double(totalDays)))
    }

    var currentDay: Int {
        min(max(1, completedDays + (isActive ? 1 : 0)), max(1, totalDays))
    }
}

struct CoachMissionsResponse: Codable, Equatable {
    let missions: [CoachMission]
}

struct CoachMissionCompletion: Codable, Equatable {
    let mission: CoachMission
    let deposit: SavingsDeposit?
}

/// The lens the Coach reasons through for a purchase — what *kind* of risk the buy carries.
/// Small buys are rarely about the price (it's the repetition); large buys are about absorption.
enum CoachPurchaseLens: Equatable {
    case habit   // small — the single price is noise; repetition is the real cost
    case pace    // medium — does this want fit this week's rhythm?
    case shock   // large — can I absorb a big hit without wrecking the goal?
}

/// Three purchase tiers that represent decision *archetypes*, not just price points.
enum CoachPurchasePreset: String, CaseIterable, Identifiable, Equatable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:  return "Coffee"
        case .medium: return "T-shirt"
        case .large:  return "New phone"
        }
    }

    var emoji: String {
        switch self {
        case .small:  return "☕"
        case .medium: return "👕"
        case .large:  return "📱"
        }
    }

    var defaultAmount: Double {
        switch self {
        case .small:  return 6
        case .medium: return 40
        case .large:  return 899
        }
    }

    /// The slider span for this tier — small buys stay small, big buys reach into the hundreds.
    var sliderRange: ClosedRange<Double> {
        switch self {
        case .small:  return 2...40
        case .medium: return 20...150
        case .large:  return 200...2000
        }
    }

    var lens: CoachPurchaseLens {
        switch self {
        case .small:  return .habit
        case .medium: return .pace
        case .large:  return .shock
        }
    }

    /// One-line framing of the question this tier really asks.
    var tagline: String {
        switch self {
        case .small:  return "It's cheap — but is it adding up?"
        case .medium: return "Does this want fit the week?"
        case .large:  return "Can I absorb a big hit without wrecking goals?"
        }
    }

    /// Representative category for the habit-signal lookup (best-effort).
    var category: FlexibleSpendingCategory {
        switch self {
        case .small:  return .coffeeRuns
        case .medium: return .shopping
        case .large:  return .shopping
        }
    }
}

struct CoachHabitSignal: Equatable {
    let label: String
    let spend: Double
    let transactionCount: Int
    let trendPercent: Double?

    static func fallback(for preset: CoachPurchasePreset) -> CoachHabitSignal {
        CoachHabitSignal(
            label: preset.category.shortName,
            spend: 0,
            transactionCount: 0,
            trendPercent: nil
        )
    }
}

enum CoachPurchaseVerdict: Equatable {
    case go
    case caution
    case skip
}

struct CoachPurchaseDecision: Equatable {
    let preset: CoachPurchasePreset
    let amount: Double
    let verdict: CoachPurchaseVerdict
    let safeBeforePurchase: Double
    let safeAfterPurchase: Double
    let habit: CoachHabitSignal
    let goalName: String?
    let goalProgress: Double?
    let headline: String
    let reason: String
    let footnote: String

    var formattedAmount: String {
        Self.currency(amount)
    }

    var formattedSafeAfterPurchase: String {
        Self.currency(safeAfterPurchase)
    }

    var riskPercent: Int {
        guard safeBeforePurchase > 0 else { return 100 }
        let ratio = min(1.0, max(0.0, amount / safeBeforePurchase))
        return Int((ratio * 100).rounded())
    }

    private static func currency(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        let body = rounded.formatted()
        return value < 0 ? "-$\(body)" : "$\(body)"
    }
}

enum CoachPurchaseDecisionEngine {
    static func evaluate(
        preset: CoachPurchasePreset,
        amount: Double,
        budgetState: BudgetStateRow?,
        habit: CoachHabitSignal,
        primaryGoal: GoalSummaryItem?,
        committedSafe: Double? = nil
    ) -> CoachPurchaseDecision {
        // Prefer the honest, trajectory-aware cushion when available; fall back to the naive pool.
        let safeBefore = committedSafe ?? (budgetState?.poolRemaining ?? 0)
        let safeAfter = safeBefore - amount
        let goalProgress = primaryGoal?.progressPercent
        let goalNeedsCash = (goalProgress ?? 1) < 0.25 || (primaryGoal?.thisMonth ?? 1) <= 0
        let repeatedHabit = habit.transactionCount >= 5
        let trendUp = (habit.trendPercent ?? 0) >= 0.15
        let eatsTooMuchWeeklyPace = amount > max(1, budgetState?.weeklyPace ?? 0) * 0.35

        // Verdict selection is shared across tiers; only the wording changes by lens.
        let verdict: CoachPurchaseVerdict
        if safeAfter < 0 {
            verdict = .skip
        } else if repeatedHabit && (goalNeedsCash || trendUp) {
            verdict = .caution
        } else if eatsTooMuchWeeklyPace && goalNeedsCash {
            verdict = .caution
        } else {
            verdict = .go
        }

        let copy = self.copy(
            lens: preset.lens,
            verdict: verdict,
            amount: amount,
            safeAfter: safeAfter,
            habit: habit,
            goal: primaryGoal,
            weeklyPace: budgetState?.weeklyPace ?? 0,
            dailyPace: budgetState?.dailyPace ?? 0
        )
        let headline = copy.headline
        let reason = copy.reason

        return CoachPurchaseDecision(
            preset: preset,
            amount: amount,
            verdict: verdict,
            safeBeforePurchase: safeBefore,
            safeAfterPurchase: safeAfter,
            habit: habit,
            goalName: primaryGoal?.name,
            goalProgress: goalProgress,
            headline: headline,
            reason: reason,
            footnote: footnote(for: habit)
        )
    }

    /// The headline + reason for a verdict, framed through the tier's lens. Small buys are
    /// coached on repetition, medium on weekly pace, large on goal absorption.
    private static func copy(
        lens: CoachPurchaseLens,
        verdict: CoachPurchaseVerdict,
        amount: Double,
        safeAfter: Double,
        habit: CoachHabitSignal,
        goal: GoalSummaryItem?,
        weeklyPace: Double,
        dailyPace: Double
    ) -> (headline: String, reason: String) {
        let goalName = goal?.name ?? "your goals"
        let amt = currency(amount)
        let safe = currency(safeAfter)
        let overBy = currency(abs(safeAfter))
        let setbackWeeks = max(1, Int((amount / max(1, goal?.weeklyRate ?? 0)).rounded(.up)))
        let daysUntil = max(1, Int((abs(safeAfter) / max(1, dailyPace)).rounded(.up)))

        switch (lens, verdict) {
        // ── Small / habit lens ──────────────────────────────────────────────
        case (.habit, .go):
            return ("One won't move the needle.",
                    "A single \(amt) \(habit.label.lowercased()) is noise. Go enjoy it — \(safe) stays safe.")
        case (.habit, .caution):
            return ("The price is tiny. The pattern is not.",
                    "\(habit.label) is already \(habit.transactionCount)x this period. The \(amt) is fine; the habit is quietly pulling cash from \(goalName).")
        case (.habit, .skip):
            return ("Even small adds up when the pool's dry.",
                    "You're \(overBy) past safe already. Hold the \(amt) until the next paycheck clears.")

        // ── Medium / pace lens ──────────────────────────────────────────────
        case (.pace, .go):
            return ("Fits the week. Go for it.",
                    "Leaves \(safe) safe and keeps \(goalName) on pace. Earned.")
        case (.pace, .caution):
            return ("Doable, but it bites the week.",
                    "This is a chunky slice of this week's \(currency(weeklyPace)) pace while \(goalName) still needs funding. Possible — just slows the goal.")
        case (.pace, .skip):
            return ("This tips the week over.",
                    "It pushes you \(overBy) past safe. Shrink it or wait — \(goalName) takes the hit otherwise.")

        // ── Large / shock lens ──────────────────────────────────────────────
        case (.shock, .go):
            return ("You can absorb this.",
                    "\(safe) still safe afterward and \(goalName) stays on track. Green light.")
        case (.shock, .caution):
            return ("You can cover it — but it costs the goal.",
                    "You can swing \(amt), but it sets \(goalName) back ~\(setbackWeeks) week\(setbackWeeks == 1 ? "" : "s"). Worth it?")
        case (.shock, .skip):
            return ("Not this month.",
                    "\(amt) overshoots your real cushion by \(overBy). Wait ~\(daysUntil) days (next paycheck) and it's a clean yes.")
        }
    }

    private static func footnote(for habit: CoachHabitSignal) -> String {
        let spend = currency(habit.spend)
        if let trend = habit.trendPercent {
            let pct = Int((abs(trend) * 100).rounded())
            let arrow = trend >= 0 ? "up" : "down"
            return "\(habit.label) - \(spend) this period - \(arrow) \(pct)%"
        }
        return "\(habit.label) - \(spend) this period"
    }

    private static func currency(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        let body = rounded.formatted()
        return value < 0 ? "-$\(body)" : "$\(body)"
    }
}

// MARK: - Service

@MainActor
class CoachService: ObservableObject {
    @Published var currentInsight: CoachInsight? = nil
    @Published var missions: [CoachMission] = []
    @Published var trajectory: SpendTrajectory? = nil
    @Published var isDismissed: Bool = false
    @Published var isLoading: Bool = false
    @Published var isLoadingMissions: Bool = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    /// Coalesces overlapping callers onto a single in-flight request so simultaneous
    /// triggers (e.g. Home's load task re-running) don't fire duplicate invokes. The 24h
    /// refresh cadence itself is owned by the server: the edge function returns its cached
    /// insight within the cooldown window, so the client doesn't gate on time at all.
    private var inFlightTask: Task<CoachInsight, Error>?

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    // MARK: - Spend Trajectory

    /// Fetch the month-end spend projection (deterministic, no LLM). Powers the honest
    /// "committed safe to spend" cushion and the biggest-driver callout on the Coach tab.
    @discardableResult
    func fetchTrajectory() async throws -> SpendTrajectory {
        do {
            let rows: [SpendTrajectoryRow] = try await supabase
                .rpc("get_spend_trajectory")
                .execute()
                .value

            let trajectory = SpendTrajectory.build(rows: rows)
            self.trajectory = trajectory
            Logger.i("CoachService: Loaded spend trajectory (\(trajectory.items.count) buckets, projected remaining \(trajectory.totalProjectedRemaining))")
            return trajectory
        } catch {
            Logger.e("CoachService: Failed to fetch spend trajectory: \(error)")
            self.error = error
            throw error
        }
    }

    // MARK: - Missions

    func fetchMissions() async throws {
        isLoadingMissions = true
        error = nil
        defer { isLoadingMissions = false }

        do {
            let result: CoachMissionsResponse = try await supabase
                .rpc("get_coach_missions")
                .execute()
                .value

            self.missions = result.missions
            Logger.i("CoachService: Loaded \(result.missions.count) coach missions")
        } catch {
            Logger.e("CoachService: Failed to fetch coach missions: \(error)")
            self.error = error
            throw error
        }
    }

    /// Start any mission type. `targetCategory` is the FlexibleSpendingCategory raw value for a
    /// category_cap (ignored by no_spend); `title`/`icon` are optional client overrides that fall
    /// back to server-derived defaults when nil.
    @discardableResult
    func startMission(
        type: CoachMissionType,
        goalId: Int?,
        projectedSavings: Double,
        dailyCap: Double = 0,
        targetCategory: String? = nil,
        title: String? = nil,
        icon: String? = nil,
        durationDays: Int = 3
    ) async throws -> CoachMission {
        struct StartCoachMissionRequest: Codable {
            let p_mission_type: String
            let p_target_goal_id: Int?
            let p_projected_savings: Double
            let p_daily_cap: Double
            let p_target_match: String?
            let p_title: String?
            let p_icon: String?
            let p_duration_days: Int
        }

        isLoadingMissions = true
        error = nil
        defer { isLoadingMissions = false }

        let body = StartCoachMissionRequest(
            p_mission_type: type.rawValue,
            p_target_goal_id: goalId,
            p_projected_savings: projectedSavings,
            p_daily_cap: dailyCap,
            p_target_match: targetCategory,
            p_title: title,
            p_icon: icon,
            p_duration_days: durationDays
        )

        do {
            let mission: CoachMission = try await supabase
                .rpc("start_coach_mission", params: body)
                .execute()
                .value

            upsertMission(mission)
            Logger.i("CoachService: Started \(type.rawValue) coach mission \(mission.id)")
            return mission
        } catch {
            Logger.e("CoachService: Failed to start coach mission: \(error)")
            self.error = error
            throw error
        }
    }

    /// Back-compat convenience for the original coffee-cap mission.
    @discardableResult
    func startCoffeeMission(goalId: Int?, projectedSavings: Double) async throws -> CoachMission {
        try await startMission(
            type: .coffeeCap,
            goalId: goalId,
            projectedSavings: projectedSavings
        )
    }

    func completeMission(id: Int, actualSavings: Double, stashToGoal: Bool) async throws -> CoachMissionCompletion {
        struct CompleteCoachMissionRequest: Codable {
            let p_mission_id: Int
            let p_actual_savings: Double
            let p_stash: Bool
        }

        isLoadingMissions = true
        error = nil
        defer { isLoadingMissions = false }

        let body = CompleteCoachMissionRequest(
            p_mission_id: id,
            p_actual_savings: actualSavings,
            p_stash: stashToGoal
        )

        do {
            let completion: CoachMissionCompletion = try await supabase
                .rpc("complete_coach_mission", params: body)
                .execute()
                .value

            upsertMission(completion.mission)
            Logger.i("CoachService: Completed coach mission \(completion.mission.id)")
            return completion
        } catch {
            Logger.e("CoachService: Failed to complete coach mission: \(error)")
            self.error = error
            throw error
        }
    }

    /// Fetch tailored financial recommendations and manga nudge insights
    func fetchCoachInsights(force: Bool = false) async throws -> CoachInsight {
        // Coalesce concurrent callers onto the same request instead of firing several.
        // The server decides whether to regenerate or return its cached insight (24h
        // cooldown), so the client always invokes and lets the backend drive the cadence.
        if let inFlight = inFlightTask {
            return try await inFlight.value
        }

        Logger.d("CoachService: Invoking gemini-coach-insights function (force: \(force))")

        let task = Task { [supabase] () throws -> CoachInsight in
            let localeId = Locale.current.language.languageCode?.identifier ?? "en"
            let body: [String: Any] = [
                "force": force,
                "locale": localeId
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            return try await supabase.functions.invoke(
                "gemini-coach-insights",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: bodyData
                )
            )
        }
        inFlightTask = task
        isLoading = true
        error = nil
        defer {
            isLoading = false
            inFlightTask = nil
        }

        do {
            let insight = try await task.value
            self.currentInsight = insight
            self.isDismissed = false
            Logger.i("CoachService: Loaded Coach insights successfully")
            return insight
        } catch {
            Logger.e("CoachService: Failed to fetch Coach insights: \(error)")
            self.error = error
            throw error
        }
    }

    /// Dismiss the current insight
    func dismissInsight() {
        self.isDismissed = true
    }

    private func upsertMission(_ mission: CoachMission) {
        if let index = missions.firstIndex(where: { $0.id == mission.id }) {
            missions[index] = mission
        } else {
            missions.insert(mission, at: 0)
        }
    }
}
