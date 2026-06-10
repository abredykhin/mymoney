import SwiftUI

struct CoachTabView: View {
    @EnvironmentObject private var coachService: CoachService
    @EnvironmentObject private var budgetService: BudgetService
    @EnvironmentObject private var goalsService: GoalsService
    @EnvironmentObject private var pulseService: PulseService
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme

    @State private var selectedPreset: CoachPurchasePreset = .medium
    @State private var selectedAmount: Double = CoachPurchasePreset.medium.defaultAmount
    @State private var selectedQuestion: CoachQuestion = .canAfford
    @State private var dismissedMissionSuggestion = false

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    private var primaryGoal: GoalSummaryItem? {
        goalsService.summary?.goals
            .filter { $0.isActive && !$0.isFunded }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.pct < rhs.pct
                }
                return lhs.priority < rhs.priority
            }
            .first
    }

    private var decision: CoachPurchaseDecision {
        CoachPurchaseDecisionEngine.evaluate(
            preset: selectedPreset,
            amount: selectedAmount,
            budgetState: budgetService.budgetState,
            habit: habitSignal(for: selectedPreset),
            primaryGoal: primaryGoal,
            committedSafe: committedSafe
        )
    }

    /// The honest, trajectory-aware cushion the "Can I?" verdict is measured against — so the
    /// answer accounts for the habit burn still coming this month, not just the raw pool.
    private var committedSafe: Double? {
        guard let pool = budgetService.budgetState?.poolRemaining,
              let trajectory = coachService.trajectory else { return nil }
        return trajectory.committedSafeToSpend(poolRemaining: pool)
    }

    private var heroCalculator: HeroBudgetCalculator? {
        guard let budgetState = budgetService.budgetState else { return nil }
        return HeroBudgetCalculator(
            budgetState: budgetState,
            spendingPlanMode: userAccount.spendingPlanMode
        )
    }

    private var monthlyCushionSnapshot: HeroCushionSnapshot? {
        guard let heroCalculator else { return nil }
        return HeroCushionSnapshot(calculator: heroCalculator, period: .month)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                CoachHeaderView(refresh: refresh)
                    .padding(.horizontal, theme.metrics.screenPadding)

                CoachReadCard(
                    insight: coachService.currentInsight,
                    budgetState: budgetService.budgetState,
                    cushionSnapshot: monthlyCushionSnapshot,
                    trajectory: coachService.trajectory,
                    primaryGoal: primaryGoal
                )
                .padding(.horizontal, theme.metrics.screenPadding)

                CoachCanICard(
                    presets: CoachPurchasePreset.allCases,
                    selectedPreset: $selectedPreset,
                    selectedAmount: $selectedAmount,
                    decision: decision,
                    onPresetSelected: { preset in
                        selectedPreset = preset
                        selectedAmount = preset.defaultAmount
                    }
                )
                .padding(.horizontal, theme.metrics.screenPadding)

                if let activeMission = activeMission {
                    CoachActiveMissionCard(
                        mission: activeMission,
                        fallbackGoalName: primaryGoal?.name ?? "Goals",
                        complete: { completeMission(activeMission) },
                        cancel: { cancelMission(activeMission) }
                    )
                    .padding(.horizontal, theme.metrics.screenPadding)
                } else if !dismissedMissionSuggestion {
                    CoachMissionSuggestionCard(
                        suggestion: suggestedMission,
                        goalName: primaryGoal?.name ?? "Goals",
                        start: { startSuggestedMission(suggestedMission) },
                        dismiss: { withAnimation(.easeInOut(duration: 0.2)) { dismissedMissionSuggestion = true } }
                    )
                    .padding(.horizontal, theme.metrics.screenPadding)
                }

                CoachQuestionDock(
                    selectedQuestion: $selectedQuestion,
                    questions: CoachQuestion.allCases
                )
                .padding(.horizontal, theme.metrics.screenPadding)

                CoachAnswerPanel(
                    selectedQuestion: selectedQuestion,
                    answer: answer(for: selectedQuestion)
                )
                .padding(.horizontal, theme.metrics.screenPadding)
            }
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .babloScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userAccount.currentUser?.id) {
            await loadCoachData(forceInsight: false)
        }
        .refreshable {
            await loadCoachData(forceInsight: true)
        }
    }

    private var topHabit: CoachHabitSignal? {
        pulseService.categoryBreakdown?
            .filter { $0.bucket != .bills && $0.totalAmount > 0 }
            .max { $0.totalAmount < $1.totalAmount }
            .map { CoachHabitSignal(from: $0) }
    }

    private var activeMission: CoachMission? {
        coachService.missions.first { $0.isActive }
    }

    private var coffeeMissionSavings: Double {
        let habit = habitSignal(for: .small)
        if habit.spend > 0 {
            return min(max(18, habit.spend * 0.55), 42)
        }
        return 24
    }

    /// The mission Coach proposes, driven by the trajectory's biggest projected leak: cap the
    /// category about to eat the most this month. Falls back to a coffee cap when there's no
    /// strong category driver yet.
    private var suggestedMission: MissionSuggestion {
        let duration = 3

        if let driver = coachService.trajectory?.topDriver,
           case let .category(category) = driver.bucket,
           driver.monthlyAverage >= 60 {
            let dailyRate = driver.monthlyAverage / 30.0
            let dailyCap = max(1, (dailyRate * 0.6).rounded())
            let savings = max(12, ((dailyRate - dailyCap) * Double(duration)).rounded())
            return MissionSuggestion(
                type: .categoryCap,
                targetCategory: category,
                title: "\(duration)-day \(category.shortName.lowercased()) cap",
                icon: category.emoji,
                blurb: "\(category.displayName) is your biggest projected leak (~\(formatCurrency(driver.projectedMonthEnd)) this month). Cap it for \(duration) days and bank the difference.",
                dailyCap: dailyCap,
                durationDays: duration,
                projectedSavings: savings
            )
        }

        if let state = budgetService.budgetState {
            let weeklyDelta = state.spentWeek - state.prevWeekSpent
            if weeklyDelta >= 25 {
                let savings = min(max(12, (weeklyDelta * 0.35).rounded()), 60)
                return MissionSuggestion(
                    type: .noSpend,
                    targetCategory: nil,
                    title: "\(duration)-day no-spend",
                    icon: "🚫",
                    blurb: "This week is \(formatCurrency(weeklyDelta)) hotter than last week. Try \(duration) no-spend days and stash the saved room.",
                    dailyCap: 0,
                    durationDays: duration,
                    projectedSavings: savings
                )
            }
        }

        // Fallback: the original coffee cap.
        return MissionSuggestion(
            type: .coffeeCap,
            targetCategory: .coffeeRuns,
            title: "\(duration)-day coffee cap",
            icon: "☕",
            blurb: "Skip café coffee for \(duration) days. Coach banks the saved amount as money ready for your goal.",
            dailyCap: 0,
            durationDays: duration,
            projectedSavings: coffeeMissionSavings
        )
    }

    private func habitSignal(for preset: CoachPurchasePreset) -> CoachHabitSignal {
        if let item = pulseService.categoryBreakdown?.first(where: { $0.bucket == .category(preset.category) }) {
            return CoachHabitSignal(from: item)
        }

        if let merchant = pulseService.topMerchants.first(where: { merchant in
            merchant.merchantName.localizedCaseInsensitiveContains(preset.title)
        }) {
            return CoachHabitSignal(
                label: preset.category.shortName,
                spend: merchant.totalSpent,
                transactionCount: merchant.transactionCount,
                trendPercent: nil
            )
        }

        return .fallback(for: preset)
    }

    private func loadCoachData(forceInsight: Bool) async {
        guard userAccount.currentUser?.id != nil else { return }

        async let budget: () = budgetService.fetchBudgetState(incomeBasis: userAccount.incomeBasis)
        async let goals: () = fetchGoalsSummary()
        async let missions: () = fetchCoachMissions()
        async let pulse: () = fetchPulseSignals()
        async let trajectory: () = fetchTrajectory()
        async let insight: () = fetchCoachInsight(force: forceInsight)
        _ = await (budget, goals, missions, pulse, trajectory, insight)
    }

    private func fetchGoalsSummary() async {
        try? await goalsService.fetchGoalsSummary()
    }

    private func fetchTrajectory() async {
        _ = try? await coachService.fetchTrajectory()
    }

    private func fetchCoachInsight(force: Bool) async {
        _ = try? await coachService.fetchCoachInsights(force: force)
    }

    private func fetchCoachMissions() async {
        try? await coachService.fetchMissions()
    }

    private func fetchPulseSignals() async {
        let window = PulsePeriod.week.currentWindow
        let comparison = PulsePeriod.week.comparisonWindow
        try? await pulseService.fetchCategoryBreakdown(
            startDate: window.startDate,
            endDate: window.endDate,
            comparisonStartDate: comparison?.startDate,
            comparisonEndDate: comparison?.endDate,
            trackedCategories: trackedCategories
        )
        await pulseService.fetchTopMerchants(startDate: window.startDate, endDate: window.endDate, limit: 8)
    }

    private func refresh() {
        Task {
            await loadCoachData(forceInsight: true)
        }
    }

    private func startSuggestedMission(_ suggestion: MissionSuggestion) {
        Task {
            do {
                _ = try await coachService.startMission(
                    type: suggestion.type,
                    goalId: primaryGoal?.id,
                    projectedSavings: suggestion.projectedSavings,
                    dailyCap: suggestion.dailyCap,
                    targetCategory: suggestion.targetCategory?.rawValue,
                    title: suggestion.title,
                    icon: suggestion.icon,
                    durationDays: suggestion.durationDays
                )
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    dismissedMissionSuggestion = false
                }
            } catch {
                Logger.e("CoachTabView: Failed to start mission: \(error)")
            }
        }
    }

    private func completeMission(_ mission: CoachMission) {
        Task {
            do {
                _ = try await coachService.completeMission(
                    id: mission.id,
                    actualSavings: mission.projectedSavings,
                    stashToGoal: mission.targetGoalId != nil
                )
                try? await goalsService.fetchGoalsSummary()
            } catch {
                Logger.e("CoachTabView: Failed to complete coach mission: \(error)")
            }
        }
    }

    private func cancelMission(_ mission: CoachMission) {
        Task {
            do {
                _ = try await coachService.cancelMission(id: mission.id)
            } catch {
                Logger.e("CoachTabView: Failed to cancel coach mission: \(error)")
            }
        }
    }

    private func answer(for question: CoachQuestion) -> String {
        let safe = budgetService.budgetState?.poolRemaining ?? 0
        let goalName = primaryGoal?.name ?? "your top goal"
        let top = topHabit?.label ?? selectedPreset.category.shortName

        switch question {
        case .canAfford:
            return decision.reason
        case .spendingMore:
            if let habit = topHabit, let trend = habit.trendPercent, trend > 0 {
                return "\(habit.label) is doing the loudest work: \(formatCurrency(habit.spend)) this week, up \(Int((trend * 100).rounded()))%. That is the first place to trim."
            }
            return "\(top) is the biggest visible lever this week. Keep the next choice small and the safe pool stays at \(formatCurrency(safe))."
        case .pause:
            return "Pause \(top.lowercased()) first. It is discretionary, visible in the week, and easier to redirect into \(goalName) than groceries or bills."
        case .moveToGoals:
            return "Skip one repeat buy and stash the amount into \(goalName). Even \(formatCurrency(coffeeMissionSavings)) this week keeps the goal moving without touching bills."
        case .goalNeedsHelp:
            if let goal = primaryGoal {
                return "\(goal.name) is at \(Int(goal.pct.rounded()))%. It wants about \(formatCurrency(goal.weeklyRate)) per week, so Coach will favor small trims over big one-off treats."
            }
            return "Add a goal and Coach can score purchases against it. Until then, the safe pool is the guardrail."
        case .changed:
            let delta = (budgetService.budgetState?.spentWeek ?? 0) - (budgetService.budgetState?.prevWeekSpent ?? 0)
            if abs(delta) < 1 {
                return "This week is flat against last week. That is boring in the best possible way."
            }
            return delta > 0
                ? "You are \(formatCurrency(delta)) above last week. Coach will get stricter on repeat habits until the week cools down."
                : "You are \(formatCurrency(abs(delta))) ahead of last week. That gives you room, but goals still get first claim."
        case .safeToday:
            let daily = budgetService.budgetState?.dailyPace ?? 0
            return "Today looks safe around \(formatCurrency(daily)). If the buy is a repeat habit, Coach still checks the pattern before giving it a green light."
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        let body = rounded.formatted()
        return value < 0 ? "-$\(body)" : "$\(body)"
    }
}

private extension CoachHabitSignal {
    init(from item: CategoryBreakdownItem) {
        let label: String
        switch item.bucket {
        case .category(let category):
            label = category.shortName
        case .bills:
            label = "Bills"
        case .rest:
            label = "Other"
        }

        self.init(
            label: label,
            spend: item.totalAmount,
            transactionCount: item.transactionCount,
            trendPercent: item.trendPercent
        )
    }
}

private enum CoachQuestion: String, CaseIterable, Identifiable {
    case canAfford
    case spendingMore
    case pause
    case moveToGoals
    case goalNeedsHelp
    case changed
    case safeToday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .canAfford: return "Can I afford sushi Friday?"
        case .spendingMore: return "Why am I spending more?"
        case .pause: return "What should I pause?"
        case .moveToGoals: return "How do I move money to goals?"
        case .goalNeedsHelp: return "Which goal needs help?"
        case .changed: return "What changed this week?"
        case .safeToday: return "What's safe today?"
        }
    }
}

private struct CoachHeaderView: View {
    let refresh: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            CoachOrb(size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Coach")
                    .font(theme.typography.title(size: 24, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.colors.success.color)
                        .frame(width: 7, height: 7)
                    Text("watching your week · live")
                        .font(theme.typography.body(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
            }

            Spacer()

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .frame(width: 44, height: 44)
                    .background(theme.colors.surface.color)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh coach")
        }
    }
}

private struct CoachReadCard: View {
    let insight: CoachInsight?
    let budgetState: BudgetStateRow?
    let cushionSnapshot: HeroCushionSnapshot?
    let trajectory: SpendTrajectory?
    let primaryGoal: GoalSummaryItem?
    @Environment(\.babloTheme) private var theme

    /// Naive pool safe-to-spend (what basic math reports).
    private var naiveSafe: Double { budgetState?.poolRemaining ?? 0 }

    /// Expected future discretionary burn from established habits.
    private var projectedRemaining: Double { trajectory?.totalProjectedRemaining ?? 0 }

    /// The honest cushion after subtracting that projected burn.
    private var committedSafe: Double { naiveSafe - projectedRemaining }

    /// Only surface the projection contrast when there's a meaningful habit burn to show.
    private var hasProjection: Bool {
        trajectory != nil && projectedRemaining >= 1 && naiveSafe > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(hasProjection ? "Projected cushion" : "Monthly cushion")
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.colors.accent.color.opacity(0.18))
                    .clipShape(Capsule())
                Spacer()
                Text(daysLeftText)
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            Text(readHeadline)
                .font(theme.typography.title(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ReadPill(title: "Spent MTD", detail: formatCurrency(budgetState?.spentMtd ?? 0), isAlert: false)
                if let driver = trajectory?.topDriver {
                    ReadPill(
                        title: driver.label,
                        detail: "~\(formatCurrency(driver.projectedMonthEnd)) proj",
                        isAlert: true
                    )
                } else {
                    ReadPill(title: "Last month", detail: formatCurrency(cushionSnapshot?.previousSpend ?? budgetState?.prevMonthSpent ?? 0), isAlert: false)
                }
                ReadPill(title: primaryGoal?.name ?? "Goal", detail: goalDetail, isAlert: false)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 6)
    }

    private var readHeadline: AttributedString {
        // Forward-looking headline: contrast the naive pool against the honest cushion left
        // after this user's habits finish burning through the month. This is the Coach's wedge.
        if hasProjection {
            let cushionFloor = max(committedSafe, 0)
            let text: String
            if committedSafe <= 1 {
                text = "Math says \(formatCurrency(naiveSafe)) safe — but your habits usually burn ~\(formatCurrency(projectedRemaining)) more this month. Real cushion ≈ \(formatCurrency(0))."
            } else {
                text = "Math says \(formatCurrency(naiveSafe)) safe — but your habits usually burn ~\(formatCurrency(projectedRemaining)) more this month. Real cushion ≈ \(formatCurrency(cushionFloor))."
            }

            var attributed = AttributedString(text)
            if let range = attributed.range(of: "~\(formatCurrency(projectedRemaining))") {
                attributed[range].foregroundColor = theme.colors.warning.color
            }
            if let range = attributed.range(of: formatCurrency(committedSafe <= 1 ? 0 : cushionFloor), options: .backwards) {
                attributed[range].foregroundColor = committedSafe <= 1 ? theme.colors.danger.color : theme.colors.success.color
            }
            return attributed
        }

        // Fallback (no projection yet): room-vs-last-month, as before.
        let safe = naiveSafe
        let roomDelta = cushionSnapshot?.roomDelta
        let delta = roomDelta ?? 0
        var text: String

        if let roomDelta, abs(roomDelta.rounded()) >= 1 {
            text = "You have \(formatCurrency(abs(roomDelta))) \(roomDelta >= 0 ? "more" : "less") room than last month - with \(formatCurrency(safe)) still safe to spend."
        } else {
            text = "You still have \(formatCurrency(safe)) safe to spend this month."
        }

        if let insight, safe <= 0 {
            text = insight.headline
        }

        var attributed = AttributedString(text)
        if let range = attributed.range(of: formatCurrency(abs(delta))), abs(delta.rounded()) >= 1 {
            attributed[range].foregroundColor = delta >= 0 ? theme.colors.success.color : theme.colors.danger.color
        }
        return attributed
    }

    private var goalDetail: String {
        guard let primaryGoal else { return "ready" }
        return "\(Int(primaryGoal.pct.rounded()))%"
    }

    private var daysLeftText: String {
        let days = budgetState?.daysRemaining ?? 0
        return days > 0 ? "\(days) days left" : "live"
    }

    private var cardBackground: some View {
        ZStack {
            theme.colors.surface.color
            RadialGradient(
                colors: [theme.colors.accent.color.opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 260
            )
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        let body = rounded.formatted()
        return value < 0 ? "-$\(body)" : "$\(body)"
    }
}

private struct ReadPill: View {
    let title: String
    let detail: String
    let isAlert: Bool
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text(detail)
                .foregroundStyle(isAlert ? theme.colors.danger.color : theme.colors.textTertiary.color)
        }
        .font(theme.typography.body(size: 12, weight: .bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
    }
}

private struct CoachCanICard: View {
    let presets: [CoachPurchasePreset]
    @Binding var selectedPreset: CoachPurchasePreset
    @Binding var selectedAmount: Double
    let decision: CoachPurchaseDecision
    let onPresetSelected: (CoachPurchasePreset) -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can I?")
                        .font(theme.typography.title(size: 18, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Text(selectedPreset.tagline)
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(decision.formattedSafeAfterPurchase)
                    Text(decision.verdict == .skip ? "after" : "safe")
                }
                .font(theme.typography.body(size: 12, weight: .bold))
                .foregroundStyle(theme.colors.textTertiary.color)
            }

            FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(presets) { preset in
                    Button {
                        onPresetSelected(preset)
                    } label: {
                        HStack(spacing: 5) {
                            Text(preset.emoji)
                            Text(preset.title)
                            Text(formatCurrency(preset.defaultAmount))
                                .foregroundStyle(selectedPreset == preset ? theme.colors.surface.color.opacity(0.72) : theme.colors.textTertiary.color)
                        }
                        .font(theme.typography.body(size: 12, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(selectedPreset == preset ? theme.colors.textPrimary.color : theme.colors.surfaceMuted.color)
                        .foregroundStyle(selectedPreset == preset ? theme.colors.surface.color : theme.colors.textPrimary.color)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .lastTextBaseline) {
                Text("AMOUNT")
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .tracking(2)
                Spacer()
                Text(formatCurrency(selectedAmount))
                    .font(theme.typography.title(size: 22, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }

            Slider(value: $selectedAmount, in: selectedPreset.sliderRange, step: 1)
                .tint(verdictColor)

            CoachDecisionResultCard(decision: decision)
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
    }

    private var verdictColor: Color {
        switch decision.verdict {
        case .go: return theme.colors.success.color
        case .caution: return theme.colors.warning.color
        case .skip: return theme.colors.danger.color
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        let body = rounded.formatted()
        return value < 0 ? "-$\(body)" : "$\(body)"
    }
}

private struct CoachDecisionResultCard: View {
    let decision: CoachPurchaseDecision
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CoachOrb(size: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(decision.headline)
                    .font(theme.typography.title(size: 16, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(decision.reason)
                    .font(theme.typography.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text("• \(decision.footnote)")
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .stroke(theme.colors.surfaceMuted.color, lineWidth: 7)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.05, min(1.0, Double(decision.riskPercent) / 100.0))))
                    .stroke(verdictColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                Text("\(decision.riskPercent)%")
                    .font(theme.typography.body(size: 12, weight: .black))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .padding(14)
        .background(resultBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(verdictColor.opacity(0.35), lineWidth: theme.metrics.borderWidth)
        }
    }

    private var verdictColor: Color {
        switch decision.verdict {
        case .go: return theme.colors.success.color
        case .caution: return theme.colors.warning.color
        case .skip: return theme.colors.danger.color
        }
    }

    private var resultBackground: some View {
        verdictColor.opacity(0.11)
    }
}

/// A concrete mission Coach proposes — derived from the trajectory's biggest leak.
struct MissionSuggestion: Equatable {
    let type: CoachMissionType
    let targetCategory: FlexibleSpendingCategory?
    let title: String
    let icon: String
    let blurb: String
    let dailyCap: Double
    let durationDays: Int
    let projectedSavings: Double
}

private struct CoachMissionSuggestionCard: View {
    let suggestion: MissionSuggestion
    let goalName: String
    let start: () -> Void
    let dismiss: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("✦ Coach suggests")
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.accentDeep.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.colors.accent.color.opacity(0.18))
                    .clipShape(Capsule())
                Spacer()
                Text("~\(formatCurrency(suggestion.projectedSavings)) → \(goalName)")
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.success.color)
            }

            Text("\(suggestion.icon) \(suggestion.title)")
                .font(theme.typography.title(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)

            Text(suggestion.blurb)
                .font(theme.typography.body(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: start) {
                    Text("Start mission ↗")
                        .font(theme.typography.body(size: 13, weight: .bold))
                        .foregroundStyle(theme.colors.surface.color)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(theme.colors.textPrimary.color)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: dismiss) {
                    Text("Maybe later")
                        .font(theme.typography.body(size: 13, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(theme.colors.surface.color)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(theme.colors.surface.color.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .foregroundStyle(theme.colors.textTertiary.color)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }

    private func formatCurrency(_ value: Double) -> String {
        "$\(Int(value.rounded()).formatted())"
    }
}

private struct CoachActiveMissionCard: View {
    let mission: CoachMission
    let fallbackGoalName: String
    let complete: () -> Void
    let cancel: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(mission.icon)
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(mission.title)
                        .font(theme.typography.title(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Spacer()
                    statusBadge
                }

                Text("Day \(mission.currentDay) of \(mission.totalDays) · \(statusText) → \(mission.goalName ?? fallbackGoalName)")
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)

                HStack(spacing: 8) {
                    ForEach(0..<max(1, mission.totalDays), id: \.self) { index in
                        Capsule()
                            .fill(index < mission.completedDays ? theme.colors.accent.color : theme.colors.surfaceMuted.color)
                            .frame(height: 8)
                    }
                }

                HStack(spacing: 10) {
                    Text("Target stash: \(formatCurrency(mission.projectedSavings))")
                        .font(theme.typography.body(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)

                    Spacer()

                    if mission.isReadyToComplete {
                        Button(action: complete) {
                            Text("Stash \(formatCurrency(mission.projectedSavings))")
                                .font(theme.typography.body(size: 13, weight: .black))
                                .foregroundStyle(theme.colors.textPrimary.color)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(theme.colors.accent.color)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: cancel) {
                            Text("Cancel")
                                .font(theme.typography.body(size: 12, weight: .bold))
                                .foregroundStyle(theme.colors.textTertiary.color)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(theme.colors.surfaceMuted.color)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func formatCurrency(_ value: Double) -> String {
        "$\(Int(value.rounded()).formatted())"
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(mission.isReadyToComplete ? "Ready" : "On track")
            .font(theme.typography.body(size: 11, weight: .bold))
            .foregroundStyle(theme.colors.accentDeep.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.colors.accent.color.opacity(0.18))
            .clipShape(Capsule())
    }

    private var statusText: String {
        if mission.completedDays == 0 {
            return "just started"
        }
        if mission.isReadyToComplete {
            return "ready to stash"
        }
        return "on track"
    }
}

private struct CoachAnswerPanel: View {
    let selectedQuestion: CoachQuestion
    let answer: String
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoachOrb(size: 32)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(selectedQuestion.title)
                    .font(theme.typography.body(size: 12, weight: .black))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(answer)
                    .font(theme.typography.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
        }
    }
}

private struct CoachQuestionDock: View {
    @Binding var selectedQuestion: CoachQuestion
    let questions: [CoachQuestion]
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask Coach")
                .font(theme.typography.title(size: 16, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)

            FlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(questions) { question in
                    Button {
                        selectedQuestion = question
                    } label: {
                        Text("✦ \(question.title)")
                            .font(theme.typography.body(size: 12, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(selectedQuestion == question ? theme.colors.textPrimary.color : theme.colors.textSecondary.color)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(selectedQuestion == question ? theme.colors.accent.color.opacity(0.18) : theme.colors.surfaceMuted.color)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
    }
}

private struct CoachOrb: View {
    let size: CGFloat
    @Environment(\.babloTheme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            theme.colors.accent.color,
                            theme.colors.success.color.opacity(0.85)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: theme.colors.accent.color.opacity(0.40), radius: 16, x: -4, y: 6)

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: size * 0.18, y: size * 0.16)
                .blur(radius: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? subviews.reduce(0) { partial, subview in
            partial + subview.sizeThatFits(.unspecified).width + horizontalSpacing
        }
        let rows = rows(for: subviews, maxWidth: maxWidth)

        return CGSize(
            width: maxWidth,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * verticalSpacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin

        for row in rows(for: subviews, maxWidth: bounds.width) {
            origin.x = bounds.minX
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: origin.x, y: origin.y),
                    proposal: ProposedViewSize(element.size)
                )
                origin.x += element.size.width + horizontalSpacing
            }
            origin.y += row.height + verticalSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = current.elements.isEmpty ? 0 : horizontalSpacing
            if current.width + spacing + size.width > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.add(subview: subview, size: size, spacing: horizontalSpacing)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        var elements: [(subview: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func add(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !elements.isEmpty {
                width += spacing
            }
            elements.append((subview, size))
            width += size.width
            height = max(height, size.height)
        }
    }
}

struct CoachTabPreviewWrapper: View {
    let theme: BabloTheme
    @StateObject private var userAccount = UserAccount()
    @StateObject private var coachService = CoachService()
    @StateObject private var budgetService = BudgetService()
    @StateObject private var goalsService = GoalsService()
    @StateObject private var pulseService = PulseService()

    init(theme: BabloTheme) {
        self.theme = theme
    }

    var body: some View {
        CoachTabView()
            .environmentObject(userAccount)
            .environmentObject(coachService)
            .environmentObject(budgetService)
            .environmentObject(goalsService)
            .environmentObject(pulseService)
            .babloTheme(theme)
            .onAppear {
                coachService.currentInsight = CoachInsight(
                    badge: "COACH · LIVE",
                    headline: "You're ahead of last week",
                    nudgeText: "Coffee is the visible repeat buy this week.",
                    actionLabel: "Open Coach",
                    alternativeTip: "Move one skipped coffee into Japan."
                )
                budgetService.budgetState = BudgetStateRow(
                    poolTotal: 900,
                    poolRemaining: 312,
                    dailyPace: 17,
                    weeklyPace: 119,
                    spentToday: 0,
                    spentWeek: 142,
                    spentMtd: 360,
                    prevDaySpent: 0,
                    prevWeekSpent: 184,
                    prevMonthSpent: 820,
                    effectiveIncome: 5_000,
                    mandatory: 3_700,
                    goalsSetAside: 0,
                    netCash: 1_200,
                    upcomingBills: 0,
                    incomeBasis: .projected,
                    daysInMonth: 30,
                    daysRemaining: 18,
                    daysElapsedInWeek: 5,
                    knownIncome: 5_000,
                    extraIncome: 0
                )
                goalsService.summary = GoalsSummary(
                    totalStashed: 840,
                    totalTarget: 2_000,
                    fundedPct: 42,
                    goalCount: 1,
                    thisMonth: 96,
                    depositoryBalance: 1_200,
                    vaultCovered: true,
                    goals: [
                        GoalSummaryItem(
                            id: 1,
                            name: "Japan",
                            categoryIcon: "✈️",
                            targetAmount: 2_000,
                            currentAmount: 840,
                            etaDate: "2026-10-01",
                            isActive: true,
                            color: "#A9F236",
                            priority: 0,
                            pct: 42,
                            weeklyRate: 24,
                            thisMonth: 96,
                            statusLabel: "on_track",
                            fundingMode: "auto_stash",
                            monthlyContribution: 96,
                            linkedAccountId: nil
                        )
                    ]
                )
                pulseService.categoryBreakdown = [
                    CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 142, transactionCount: 2, percentOfTotal: 0.6, previousAmount: 103),
                    CategoryBreakdownItem(bucket: .category(.coffeeRuns), totalAmount: 42, transactionCount: 6, percentOfTotal: 0.18, previousAmount: 34)
                ]
            }
    }
}

#Preview("Coach Normal") {
    CoachTabPreviewWrapper(theme: .normal)
}

#Preview("Coach Pop") {
    CoachTabPreviewWrapper(theme: .pop)
}
