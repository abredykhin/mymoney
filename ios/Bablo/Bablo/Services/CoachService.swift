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
    case coffeeCap = "coffee_cap"
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

enum CoachPurchasePreset: String, CaseIterable, Identifiable, Equatable {
    case coffee
    case sushi
    case concert
    case rideshare
    case shopping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coffee: return "Coffee"
        case .sushi: return "Sushi"
        case .concert: return "Concert"
        case .rideshare: return "Ride"
        case .shopping: return "Shopping"
        }
    }

    var emoji: String {
        switch self {
        case .coffee: return "☕"
        case .sushi: return "🍣"
        case .concert: return "🎟️"
        case .rideshare: return "🚗"
        case .shopping: return "🛍️"
        }
    }

    var defaultAmount: Double {
        switch self {
        case .coffee: return 6
        case .sushi: return 48
        case .concert: return 124
        case .rideshare: return 22
        case .shopping: return 75
        }
    }

    var category: FlexibleSpendingCategory {
        switch self {
        case .coffee: return .coffeeRuns
        case .sushi: return .eatsOut
        case .concert: return .fun
        case .rideshare: return .gettingAround
        case .shopping: return .shopping
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
        primaryGoal: GoalSummaryItem?
    ) -> CoachPurchaseDecision {
        let safeBefore = budgetState?.poolRemaining ?? 0
        let safeAfter = safeBefore - amount
        let goalProgress = primaryGoal?.progressPercent
        let goalNeedsCash = (goalProgress ?? 1) < 0.25 || (primaryGoal?.thisMonth ?? 1) <= 0
        let repeatedHabit = habit.transactionCount >= 5
        let trendUp = (habit.trendPercent ?? 0) >= 0.15
        let eatsTooMuchWeeklyPace = amount > max(1, budgetState?.weeklyPace ?? 0) * 0.35

        let verdict: CoachPurchaseVerdict
        let headline: String
        let reason: String

        if safeAfter < 0 {
            verdict = .skip
            headline = "Skip this one."
            reason = "\(preset.title) would overspend your safe pool by \(currency(abs(safeAfter))). Push that money toward \(primaryGoal?.name ?? "a goal") instead."
        } else if repeatedHabit && (goalNeedsCash || trendUp) {
            verdict = .caution
            headline = "The price is tiny. The pattern is not."
            reason = "\(habit.label) is already \(habit.transactionCount)x this period. The \(currency(amount)) is affordable, but the habit is pulling cash away from \(primaryGoal?.name ?? "your goals")."
        } else if eatsTooMuchWeeklyPace && goalNeedsCash {
            verdict = .caution
            headline = "Possible, but it slows the goal."
            reason = "This leaves \(currency(safeAfter)) safe, but it is a chunky bite of this week's pace while \(primaryGoal?.name ?? "your goal") needs funding."
        } else {
            verdict = .go
            headline = "Treat earned. Go for it."
            reason = "A one-off, not a habit - leaves \(currency(safeAfter)) safe and keeps \(primaryGoal?.name ?? "your goals") untouched."
        }

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

    func startCoffeeMission(goalId: Int?, projectedSavings: Double) async throws -> CoachMission {
        struct StartCoachMissionRequest: Codable {
            let p_mission_type: String
            let p_target_goal_id: Int?
            let p_projected_savings: Double
            let p_daily_cap: Double
        }

        isLoadingMissions = true
        error = nil
        defer { isLoadingMissions = false }

        let body = StartCoachMissionRequest(
            p_mission_type: CoachMissionType.coffeeCap.rawValue,
            p_target_goal_id: goalId,
            p_projected_savings: projectedSavings,
            p_daily_cap: 0
        )

        do {
            let mission: CoachMission = try await supabase
                .rpc("start_coach_mission", params: body)
                .execute()
                .value

            upsertMission(mission)
            Logger.i("CoachService: Started coach mission \(mission.id)")
            return mission
        } catch {
            Logger.e("CoachService: Failed to start coach mission: \(error)")
            self.error = error
            throw error
        }
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
