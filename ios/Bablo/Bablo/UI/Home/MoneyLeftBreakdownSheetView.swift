import SwiftUI

struct MoneyLeftBreakdownView: View {
    @EnvironmentObject private var budgetService: BudgetService
    @EnvironmentObject private var accountsService: AccountsService
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme

    let period: HeroPeriod

    @State private var spendRows: [HeroSpendBreakdownRow] = []
    @State private var incomeRows: [HeroIncomeBreakdownRow] = []
    @State private var excludedTransactionRows: [HeroExcludedTransactionRow] = []
    @State private var recentPaymentDates: [String: String] = [:]
    @State private var isLoadingDetails = false
    /// The period whose details are currently loaded. Guards against a redundant
    /// reload (and its loading flicker) when this view reappears after a pushed
    /// transaction list is popped — `.task(id:)` restarts on reappear.
    @State private var loadedPeriod: HeroPeriod?

    private var calculator: HeroBudgetCalculator {
        let cal = Calendar.bablo
        let now = Date()
        let currentWeekStartDate = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let daysElapsedInWeek = (cal.dateComponents([.day], from: currentWeekStartDate, to: now).day ?? 0) + 1
        return HeroBudgetCalculator(
            monthlyIncome: budgetService.monthlyIncome,
            monthlyMandatoryExpenses: budgetService.monthlyMandatoryExpenses,
            knownIncomeThisMonth: budgetService.knownIncomeThisMonth,
            extraIncomeThisMonth: budgetService.extraIncomeThisMonth,
            variableSpend: budgetService.variableSpend,
            currentWeekVariableSpend: budgetService.currentWeekVariableSpend,
            todayVariableSpend: budgetService.todayVariableSpend,
            liquidCashAvailable: budgetService.totalBalance?.balance,
            spendingPlanMode: userAccount.spendingPlanMode,
            upcomingUnpaidExpenses: budgetService.upcomingUnpaidBills,
            previousDayVariableSpend: budgetService.previousDayVariableSpend,
            previousWeekVariableSpend: budgetService.previousWeekVariableSpend,
            previousMonthVariableSpend: budgetService.previousMonthVariableSpend,
            dayOfMonth: cal.component(.day, from: now),
            daysInMonth: cal.range(of: .day, in: .month, for: now)?.count ?? 30,
            daysElapsedInWeek: daysElapsedInWeek
        )
    }

    private var breakdown: HeroBudgetBreakdownCalculator {
        HeroBudgetBreakdownCalculator(calculator: calculator, period: period)
    }

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    /// Mandatory expense streams for the obligations step, sorted by monthly amount descending.
    private var mandatoryRows: [HeroBudgetMandatoryRow] {
        let cal = Calendar.bablo
        let now = Date()
        guard let lookahead = cal.date(byAdding: .day, value: 14, to: now) else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = cal.timeZone
        let todayStr = fmt.string(from: now)
        let lookaheadStr = fmt.string(from: lookahead)

        let comingUp = ComingUpCalculator(
            subscriptions: budgetService.allRecurringStreams,
            currentDate: now,
            timeZone: cal.timeZone,
            recentPaymentDates: recentPaymentDates
        )

        return budgetService.allRecurringStreams
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
            .prefix(6)
            .map { stream in
                let isUpcoming: Bool = {
                    guard let d = stream.predictedNextDate else { return false }
                    // Don't badge a bill "due soon" if its current occurrence already posted.
                    guard !comingUp.isPaidThisCycle(stream) else { return false }
                    return d >= todayStr && d <= lookaheadStr
                }()
                return HeroBudgetMandatoryRow(
                    id: stream.id,
                    name: stream.merchantName ?? stream.description,
                    monthlyAmount: stream.monthlyAmount,
                    averageAmount: stream.averageAmount,
                    frequency: stream.frequency,
                    isUpcoming: isUpcoming,
                    frequencyDisplay: stream.frequencyDisplay
                )
            }
    }

    private var accountAuditRows: HeroBudgetAccountAuditRows {
        let inputs = accountsService.banksWithAccounts.flatMap { bank in
            bank.accounts.map {
                HeroBudgetAccountInput(
                    name: $0.name,
                    mask: $0.mask,
                    type: $0.type,
                    currentBalance: $0.currentBalance
                )
            }
        }
        return HeroBudgetBreakdownCalculator.accountAuditRows(accounts: inputs)
    }

    private var periodPhrase: String {
        switch period {
        case .day: return "safe to spend today"
        case .week: return "safe to spend this week"
        case .month: return "safe to spend this month"
        }
    }

    /// Subtitle for the projected "Expected paycheck" row, including the soonest
    /// upcoming income stream's predicted date (e.g. "expected Fri, Jun 5 · not yet received").
    /// Falls back to nil when no income stream has a usable future date, in which case
    /// the row shows its default "expected · not yet received" copy.
    private var nextPaycheckDetail: String? {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = Calendar.bablo.timeZone
        let todayStr = parser.string(from: Date())

        let next = budgetService.allRecurringStreams
            .filter { $0.type == "income" && $0.isActive && !$0.isExcluded }
            .compactMap { $0.predictedNextDate }
            .filter { $0 >= todayStr }
            .min()

        guard let next, let date = parser.date(from: next) else { return nil }
        let display = DateFormatter()
        display.dateFormat = "EEE, MMM d"
        display.locale = Locale(identifier: "en_US_POSIX")
        return "expected \(display.string(from: date)) · not yet received"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                amountHero
                explainer
                steps
                whatsLeftCard
                accountAudit
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .babloScreenBackground()
        .navigationTitle("How we got this")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: period) {
            await loadDetails()
        }
    }

    /// Large amount displayed at the top of the scrollable content,
    /// replacing the fixed header that belonged to the old sheet presentation.
    private var amountHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(moneyStr(breakdown.finalAmount))
                .font(theme.typography.display(size: 52, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("\(periodPhrase) · \(period.topBarLabel.capitalized)")
                .font(theme.typography.body(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var explainer: some View {
        Text("Follow the money. Each step pulls a chunk out until you're left with what's actually yours to spend.")
            .font(theme.typography.body(size: 15, weight: .regular))
            .foregroundStyle(theme.colors.textSecondary.color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.colors.line.color)
                    .frame(height: 1)
            }
    }

    private var steps: some View {
        VStack(spacing: 0) {
            ForEach(Array(breakdown.steps.enumerated()), id: \.element.id) { idx, step in
                // Map the step's transaction source to a navigation destination.
                // Steps with nil source (calculated values) are non-tappable.
                // The variable-spend step opens the same Recent-style list as the
                // "Recent" widget (scoped to this period) instead of a bespoke list.
                let navDest: HomeDestination? = step.transactionSource.map { source in
                    switch source {
                    case .variableSpend: return .periodSpendList(period)
                    case .income, .obligations: return .breakdownTransactions(source, period, nil)
                    }
                }

                BreakdownStepCard(
                    step: step,
                    period: period,
                    contextRows: step.number == 1 ? breakdown.contextRows : [],
                    spendRows: step.number == breakdown.spendStepNumber ? spendRows : [],
                    incomeRows: period == .month && !breakdown.isCashCapped && step.number == 1 ? incomeRows : [],
                    mandatoryRows: step.number == breakdown.mandatoryStepNumber ? mandatoryRows : [],
                    isLoading: isLoadingDetails && step.number == breakdown.spendStepNumber,
                    navigationDestination: navDest
                )

                if idx < breakdown.steps.count - 1 {
                    stepConnector
                }
            }
        }
    }

    private var stepConnector: some View {
        ZStack {
            Rectangle()
                .fill(theme.colors.line.color)
                .frame(width: 2, height: 20)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.colors.textTertiary.color)
                .offset(y: 7)
        }
        .frame(width: 2)
        .padding(.leading, 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whatsLeftCard: some View {
        VStack(spacing: 4) {
            Text("= WHAT'S LEFT")
                .font(theme.typography.body(size: 13, weight: .black))
                .tracking(3)
                .foregroundStyle(whatsLeftToneColor)
            Text(moneyStr(breakdown.finalAmount))
                .font(theme.typography.display(size: 58, weight: .black))
                .foregroundStyle(whatsLeftAmountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(periodPhrase)
                .font(theme.typography.body(size: 16, weight: .bold))
                .foregroundStyle(whatsLeftToneColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(whatsLeftBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(whatsLeftStrokeColor, lineWidth: 2)
        }
    }

    private var accountAudit: some View {
        VStack(spacing: 12) {
            AccountAuditCard(
                title: "WHERE YOUR MONEY SITS RIGHT NOW",
                trailing: "\(moneyStr(accountAuditRows.countedTotal)) liquid",
                rows: accountAuditRows.counted
            )

            if !excludedTransactionRows.isEmpty {
                DisclosureGroup {
                    ExcludedTransactionRowsList(rows: excludedTransactionRows)
                        .padding(.top, 8)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NOT COUNTED")
                                .font(theme.typography.body(size: 13, weight: .black))
                                .tracking(3)
                                .foregroundStyle(theme.colors.textTertiary.color)
                            Text("\(excludedTransactionRows.count) transactions")
                                .font(theme.typography.body(size: 12, weight: .semibold))
                                .foregroundStyle(theme.colors.textTertiary.color)
                        }
                        Spacer()
                        Text("why these\naren't in spend")
                            .font(theme.typography.body(size: 12, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .tint(theme.colors.textTertiary.color)
                .padding(16)
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                        .stroke(
                            theme.colors.lineStrong.color,
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 5])
                        )
                }
            }
        }
    }

    private func loadDetails() async {
        // Already loaded for this period — skip the refetch (and its flicker) that
        // would otherwise fire when the view reappears after a pushed list is popped.
        guard loadedPeriod != period else { return }
        isLoadingDetails = true
        async let spend = budgetService.fetchHeroSpendBreakdownRows(for: period, trackedCategories: trackedCategories)
        async let income = period == .month ? budgetService.fetchHeroIncomeRowsForCurrentMonth() : []
        async let excluded = budgetService.fetchHeroExcludedTransactionRows(for: period)
        async let paid = period == .month ? budgetService.fetchRecentExpenseMerchantDates() : [:]
        let (loadedSpend, loadedIncome, loadedExcluded, loadedPaid) = await (spend, income, excluded, paid)
        recentPaymentDates = loadedPaid
        spendRows = loadedSpend
        // The "Income this month" total is effectiveIncome, which leans on an expected
        // paycheck before it lands. Surface that projected portion as its own row so the
        // total isn't unexplained when no income has been received yet this month.
        let projected = calculator.expectedIncomeStillToCome
        if period == .month, projected >= 1 {
            incomeRows = loadedIncome + [
                HeroIncomeBreakdownRow(
                    name: "Expected paycheck",
                    amount: projected,
                    isRecurring: true,
                    isProjected: true,
                    detailOverride: nextPaycheckDetail
                )
            ]
        } else {
            incomeRows = loadedIncome
        }
        excludedTransactionRows = loadedExcluded
        loadedPeriod = period
        isLoadingDetails = false
    }

    private func moneyStr(_ v: Double) -> String {
        let amount = Int(v.rounded())
        if amount < 0 { return "-$\(abs(amount).formatted())" }
        return "$\(amount.formatted())"
    }

    private var isNegativeFinalAmount: Bool {
        breakdown.finalAmount < 0
    }

    private var whatsLeftToneColor: Color {
        isNegativeFinalAmount ? theme.colors.danger.color : theme.colors.accentDeep.color
    }

    private var whatsLeftAmountColor: Color {
        isNegativeFinalAmount ? theme.colors.danger.color : theme.colors.accentInk.color
    }

    private var whatsLeftBackgroundColor: Color {
        (isNegativeFinalAmount ? theme.colors.danger.color : theme.colors.accent.color).opacity(0.18)
    }

    private var whatsLeftStrokeColor: Color {
        (isNegativeFinalAmount ? theme.colors.danger.color : theme.colors.accentPressed.color).opacity(0.7)
    }
}

// MARK: - Step card

private struct BreakdownStepCard: View {
    @Environment(\.babloTheme) private var theme

    let step: HeroBudgetBreakdownStep
    let period: HeroPeriod
    let contextRows: [HeroBudgetContextRow]
    let spendRows: [HeroSpendBreakdownRow]
    let incomeRows: [HeroIncomeBreakdownRow]
    let mandatoryRows: [HeroBudgetMandatoryRow]
    let isLoading: Bool
    /// When non-nil, the step header becomes a NavigationLink to this destination.
    let navigationDestination: HomeDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step header — tappable when navigationDestination is set
            if let dest = navigationDestination {
                NavigationLink(value: dest) {
                    stepHeaderContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                stepHeaderContent
            }

            // Income sub-rows (step 1 in monthly income mode)
            if !incomeRows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(incomeRows) { row in
                        SheetInfoRow(
                            symbol: incomeRowSymbol(for: row),
                            title: row.name,
                            detail: incomeRowDetail(for: row),
                            amount: row.amount,
                            isNegative: false
                        )
                    }
                }
            }

            // Mandatory obligation rows (step 2 in monthly income mode)
            if !mandatoryRows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(mandatoryRows) { row in
                        SheetInfoRow(
                            symbol: row.isUpcoming ? "calendar.badge.exclamationmark" : "lock.fill",
                            title: row.name,
                            detail: mandatoryDetail(for: row),
                            amount: row.monthlyAmount,
                            isNegative: true
                        )
                    }
                }
            }

            // Spend sub-rows (last step)
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else if !spendRows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(spendRows) { row in
                        if let _ = navigationDestination {
                            let categoryDest = HomeDestination.breakdownTransactions(step.transactionSource ?? .variableSpend, period, row.category)
                            NavigationLink(value: categoryDest) {
                                SheetInfoRow(
                                    symbol: categorySymbol(for: row.category),
                                    title: row.category,
                                    detail: row.detail,
                                    amount: row.amount,
                                    isNegative: true,
                                    isTappable: true
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            SheetInfoRow(
                                symbol: categorySymbol(for: row.category),
                                title: row.category,
                                detail: row.detail,
                                amount: row.amount,
                                isNegative: true,
                                isTappable: false
                            )
                        }
                    }
                }
            }

            // Context rows — only used for week/day to show monthly cap
            if !contextRows.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(contextRows) { row in
                        HStack(spacing: 8) {
                            Image(systemName: row.amount < 0 ? "lock.fill" : "info.circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.colors.textTertiary.color)
                                .frame(width: 18)

                            Text(row.title)
                                .font(theme.typography.body(size: 13, weight: .medium))
                                .foregroundStyle(theme.colors.textTertiary.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 4)

                            let abs = Int(abs(row.amount).rounded())
                            Text(row.amount < 0 ? "-$\(abs.formatted())" : "$\(abs.formatted())")
                                .font(theme.typography.mono(size: 13, weight: .semibold))
                                .foregroundStyle(theme.colors.textTertiary.color)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // After-this-step footer
            HStack {
                Spacer()
                Text("AFTER THIS STEP")
                    .font(theme.typography.body(size: 12, weight: .black))
                    .tracking(3)
                    .foregroundStyle(theme.colors.textTertiary.color)
                Text(money(step.afterAmount))
                    .font(theme.typography.body(size: 16, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.colors.surfaceMuted.color)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The header row shared by both the plain and NavigationLink variants.
    private var stepHeaderContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Numbered badge
            Text("\(step.number)")
                .font(theme.typography.body(size: 16, weight: .black))
                .foregroundStyle(step.tone == .positive ? .white : theme.colors.surface.color)
                .frame(width: 34, height: 34)
                .background(stepColor)
                .clipShape(Circle())

            // Title — the primary tap label
            Text(step.title)
                .font(theme.typography.title(size: 16, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Signed amount
            Text(signedMoney(step.amount))
                .font(theme.typography.mono(size: 21, weight: .bold))
                .foregroundStyle(step.amount < 0 ? theme.colors.warning.color : theme.colors.success.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)

            // Chevron: only shown on tappable steps to signal drilldown
            if navigationDestination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }
        }
    }

    private var stepColor: Color {
        switch step.tone {
        case .positive: return theme.colors.success.color
        case .neutral:  return theme.colors.textTertiary.color
        case .negative: return Color(hex: "#9B8B76") ?? theme.colors.warning.color
        }
    }

    private func categorySymbol(for category: String) -> String {
        switch category {
        case "Eats out":           return "fork.knife"
        case "Coffee runs":        return "cup.and.saucer.fill"
        case "Groceries":          return "cart.fill"
        case "Fun":                return "gamecontroller.fill"
        case "Shopping":           return "bag.fill"
        case "Getting around":     return "car.fill"
        case "Self-care":          return "figure.mind.and.body"
        case "Travel":             return "airplane"
        case "Everything else":    return "square.grid.2x2.fill"
        case "Food & Drink":       return "cup.and.saucer.fill"
        case "Transportation":     return "car.fill"
        case "Personal Care":      return "figure.run"
        case "Entertainment":      return "gamecontroller.fill"
        case "Services":           return "wrench.and.screwdriver.fill"
        case "Transfers & Cash":   return "arrow.left.arrow.right"
        case "Home":               return "house.fill"
        case "Medical":            return "cross.fill"
        case "Donations":          return "hands.and.sparkles.fill"
        case "Bills":              return "doc.text.fill"
        case "Bank Fees":          return "building.columns.fill"
        case "Loan Payments":      return "creditcard.fill"
        default:
            // Fallback for any unmapped category
            let lower = category.lowercased()
            if lower.contains("food")          { return "cup.and.saucer.fill" }
            if lower.contains("transport")     { return "car.fill" }
            if lower.contains("entertainment") { return "gamecontroller.fill" }
            if lower.contains("shop")          { return "bag.fill" }
            return "creditcard.fill"
        }
    }

    private func incomeRowSymbol(for row: HeroIncomeBreakdownRow) -> String {
        if row.isProjected { return "hourglass" }
        return row.isRecurring ? "briefcase.fill" : "arrow.turn.down.left"
    }

    private func incomeRowDetail(for row: HeroIncomeBreakdownRow) -> String {
        if let detailOverride = row.detailOverride { return detailOverride }
        if row.isProjected { return "expected · not yet received" }
        return row.isRecurring ? "recurring" : "extra"
    }

    private func mandatoryDetail(for row: HeroBudgetMandatoryRow) -> String {
        var parts: [String] = [row.frequencyDisplay]
        if let perOcc = perOccurrenceDetail(frequency: row.frequency, amount: row.averageAmount) {
            parts.append(perOcc)
        }
        if row.isUpcoming { parts.append("due soon") }
        return parts.joined(separator: " · ")
    }

    private func perOccurrenceDetail(frequency: String, amount: Double) -> String? {
        let rounded = Int(amount.rounded())
        let fmt = "$\(rounded.formatted())"
        switch frequency {
        case "WEEKLY":      return "\(fmt)/wk"
        case "SEMI_MONTHLY": return "\(fmt)/2wk"
        case "ANNUALLY":    return "\(fmt)/yr"
        default:            return nil
        }
    }

    private func signedMoney(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded < 0 { return "-$\(abs(rounded).formatted())" }
        return "+$\(rounded.formatted())"
    }

    private func money(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded < 0 { return "-$\(abs(rounded).formatted())" }
        return "$\(rounded.formatted())"
    }
}

// MARK: - Row components

private struct SheetInfoRow: View {
    @Environment(\.babloTheme) private var theme

    let symbol: String
    let title: String
    let detail: String
    let amount: Double
    let isNegative: Bool
    var isTappable: Bool = false

    private var categoryEmoji: String? {
        FlexibleSpendingCategory.allCases.first(where: { $0.displayName == title })?.emoji
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let emoji = categoryEmoji {
                Text(emoji)
                    .font(.system(size: 16))
                    .frame(width: 22)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.body(size: 15, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !detail.isEmpty {
                    Text(detail)
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            Text(amountText)
                .font(theme.typography.mono(size: 16, weight: .bold))
                .foregroundStyle(isNegative ? theme.colors.textSecondary.color : theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            
            if isTappable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountText: String {
        let rounded = Int(abs(amount).rounded())
        return "$\(rounded.formatted())"
    }
}

private struct AccountAuditCard: View {
    @Environment(\.babloTheme) private var theme

    let title: String
    let trailing: String
    let rows: [HeroBudgetAccountAuditRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(theme.typography.body(size: 13, weight: .black))
                    .tracking(3)
                    .foregroundStyle(theme.colors.textTertiary.color)
                Text(trailing)
                    .font(theme.typography.mono(size: 20, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            AccountRowsList(rows: rows)
        }
        .padding(16)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
    }
}

private struct AccountRowsList: View {
    @Environment(\.babloTheme) private var theme

    let rows: [HeroBudgetAccountAuditRow]

    var body: some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text("No visible accounts in this group yet")
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(theme.typography.body(size: 16, weight: .black))
                                .foregroundStyle(theme.colors.textPrimary.color)
                                .lineLimit(1)
                            Text(row.detail)
                                .font(theme.typography.body(size: 14, weight: .regular))
                                .foregroundStyle(theme.colors.textTertiary.color)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(row.displayAmount)
                            .font(theme.typography.mono(size: 16, weight: .bold))
                            .foregroundStyle(row.amount < 0 ? theme.colors.danger.color : theme.colors.textPrimary.color)
                    }
                    .padding(.vertical, 8)

                    if row.id != rows.last?.id {
                        Rectangle()
                            .fill(theme.colors.line.color)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

private struct ExcludedTransactionRowsList: View {
    @Environment(\.babloTheme) private var theme

    let rows: [HeroExcludedTransactionRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(theme.typography.body(size: 16, weight: .black))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .lineLimit(1)
                        Text(row.detail)
                            .font(theme.typography.body(size: 13, weight: .regular))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(row.displayAmount)
                        .font(theme.typography.mono(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .layoutPriority(1)
                        .padding(.top, 2)
                }
                .padding(.vertical, 8)

                if row.id != rows.last?.id {
                    Rectangle()
                        .fill(theme.colors.line.color)
                        .frame(height: 1)
                }
            }
        }
    }
}
