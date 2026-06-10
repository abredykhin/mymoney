//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI
import Network

struct HomeView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject private var transactionsService: TransactionsService
    @EnvironmentObject private var budgetService: BudgetService
    @EnvironmentObject private var userAccount: UserAccount
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject private var coachService: CoachService
    @EnvironmentObject private var streakService: StreakService
    @EnvironmentObject private var subService: SubscriptionsService
    @EnvironmentObject private var pulseService: PulseService
    @State private var isOffline = false
    @State private var isRefreshing = false
    @State private var showingOnboarding = false
    @State private var showingCushionSheet = false
    @State private var networkMonitor: NWPathMonitor?
    @State private var heroPeriod: HeroPeriod = .month
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active
    private let loadsData: Bool

    init(loadsData: Bool = true) {
        self.loadsData = loadsData
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.sectionSpacing) {
                HomeTopBarView(dateRangeLabel: homeTopBarLabel)


                if isOffline {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("You're offline. Showing cached data.")
                        Spacer()
                        Button("Try Again") {
                            checkConnectivityAndRefresh()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(Spacing.md)
                    .background(ColorPalette.warning.opacity(0.2))
                    .cornerRadius(CornerRadius.sm)
                    .padding(.horizontal, Spacing.screenEdge)
                }
                
                let hasBudgetData = budgetService.monthlyIncome > 0 || budgetService.monthlyMandatoryExpenses > 0
                let hasBankAccounts = !accountsService.visibleBanksWithAccounts.isEmpty

                let shouldShowMoneyWidgets = hasBudgetData || hasBankAccounts || !transactionsService.transactions.isEmpty

                if hasBudgetData || hasBankAccounts {
                    LiquidHeroView(period: $heroPeriod, onTap: {
                        navigationState.homeNavPath.append(
                            HomeDestination.budgetBreakdown(heroPeriod)
                        )
                    }, onDeltaTap: {
                        showingCushionSheet = true
                        if loadsData {
                            Task { await loadCushionSheetData() }
                        }
                    })
                    .environmentObject(budgetService)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.md)
                }

                if !accountsService.visibleBanksWithAccounts.isEmpty && coachService.currentInsight != nil && !coachService.isDismissed {
                    CoachCardView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }

                // 2c. Secondary money widgets
                if shouldShowMoneyWidgets {
                    if hasBankAccounts {
                        HStack(spacing: Spacing.md) {
                            StreakWidgetView {
                                navigationState.homeNavPath.append(HomeDestination.streakDetail)
                            }
                            SubsWidgetView()
                        }
                        .padding(.horizontal, Spacing.screenEdge)
                    }

                    ComingUpWidgetView()
                        .padding(.horizontal, Spacing.screenEdge)

                    RecentWidgetView()
                        .padding(.horizontal, Spacing.screenEdge)
                }

                // Empty state only when no budget data and no bank accounts
                if !hasBudgetData && !hasBankAccounts {
                    HeroBudgetEmptyStateView()
                        .onTapGesture {
                            showingOnboarding = true
                        }
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(.bottom, 96)
        }
        .navigationDestination(for: HomeDestination.self) { destination in
            switch destination {
            case .budgetBreakdown(let period):
                MoneyLeftBreakdownView(period: period)
            case .categorySpendList(let period, let category):
                let range = periodSpendDateRange(for: period)
                let initialFilter: TransactionFilterValue = {
                    if let cat = FlexibleSpendingCategory.allCases.first(where: { $0.displayName == category }) {
                        return .category(cat)
                    } else if category == "Everything else" {
                        return .other
                    } else {
                        return .out
                    }
                }()
                AllTransactionsView(
                    startDate: range.start,
                    endDate: range.end,
                    title: category,
                    initialFilter: initialFilter,
                    discretionaryOnly: true
                )
            case .incomeTransactions:
                let range = periodSpendDateRange(for: .month)
                AllTransactionsView(
                    startDate: range.start,
                    endDate: range.end,
                    title: "Income this month",
                    initialFilter: .income
                )
            case .obligationsDetails:
                ComingUpDetailsSheetView()
            case .streakDetail:
                StreakDetailView()
            case .allTransactions:
                AllTransactionsView()
            case .periodSpendList(let period):
                let range = periodSpendDateRange(for: period)
                AllTransactionsView(
                    startDate: range.start,
                    endDate: range.end,
                    title: periodSpendListTitle(for: period),
                    initialFilter: .out,
                    discretionaryOnly: true
                )
            case .monthSpendBeforePeriod(let period):
                let range = monthBeforePeriodDateRange(for: period)
                AllTransactionsView(
                    startDate: range.start,
                    endDate: range.end,
                    title: "Spent earlier this month",
                    initialFilter: .out,
                    discretionaryOnly: true
                )
            case .dayTransactions(let dateStr):
                // Streak day drill-down: show only discretionary spend (the
                // `variable_transactions` that drive the day's budget/streak calc).
                AllTransactionsView(
                    startDate: dateStr,
                    endDate: dateStr,
                    title: formatDisplayDate(dateStr),
                    initialFilter: .all,
                    discretionaryOnly: true
                )
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingWizard()
        }
        .sheet(isPresented: $showingCushionSheet) {
            if let snapshot = cushionSnapshot {
                TheCushionSheetView(
                    snapshot: snapshot,
                    period: heroPeriod.pulsePeriod,
                    breakdown: pulseService.cushionBreakdown ?? [],
                    dailySeries: pulseService.cushionDailySeries,
                    isLoading: pulseService.isLoadingCushion,
                    dismissAction: { showingCushionSheet = false },
                    primaryAction: {
                        showingCushionSheet = false
                        navigationState.selectedTab = snapshot.hasMoreRoom ? .goals : .pulse
                    }
                )
                .presentationDetents([PresentationDetent.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .refreshable {
            guard loadsData else { return }
            checkConnectivityAndRefresh()
        }
        .task(id: userAccount.currentUser?.id) {
            guard loadsData else { return }
            await refreshHomeForCurrentUser()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard loadsData else {
                previousScenePhase = newPhase
                return
            }
            // Returning to the foreground while Home is already on screen: the id-keyed
            // .task won't re-run, so transactions that synced while we were away would
            // otherwise only appear after a manual pull-to-refresh. Refresh the feed now.
            if newPhase == .active,
               previousScenePhase == .background || previousScenePhase == .inactive {
                Task { await refreshRecentTransactionsOnForeground() }
            }
            previousScenePhase = newPhase
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check network status when view appears
            if loadsData {
                checkNetworkStatus()
            }
        }
        .onDisappear {
            networkMonitor?.cancel()
            networkMonitor = nil
        }
    }
    
    private var homeTopBarLabel: String {
        heroPeriod.topBarLabel
    }

    private var cushionSnapshot: HeroCushionSnapshot? {
        HeroCushionSnapshot(calculator: heroCalculator, period: heroPeriod)
    }

    private var heroCalculator: HeroBudgetCalculator {
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
            upcomingUnpaidExpenses: subService.upcomingUnpaidBills,
            previousDayVariableSpend: budgetService.previousDayVariableSpend,
            previousWeekVariableSpend: budgetService.previousWeekVariableSpend,
            previousMonthVariableSpend: budgetService.previousMonthVariableSpend,
            dayOfMonth: cal.component(.day, from: now),
            daysInMonth: cal.range(of: .day, in: .month, for: now)?.count ?? 30,
            daysElapsedInWeek: daysElapsedInWeek,
            budgetState: budgetService.budgetState
        )
    }

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    /// Date window (yyyy-MM-dd) for the Recent-style spend list opened from a
    /// breakdown step — matches the period the hero step summarizes (month-to-date,
    /// week-to-date, or just today).
    private func periodSpendDateRange(for period: HeroPeriod) -> (start: String, end: String) {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = cal.timeZone

        let startDate: Date
        switch period {
        case .day:
            startDate = cal.startOfDay(for: now)
        case .week:
            startDate = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        case .month:
            startDate = cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
        }
        return (fmt.string(from: startDate), fmt.string(from: now))
    }

    /// Date window (yyyy-MM-dd) for "Spent earlier this month": from the start of the month up to
    /// the day BEFORE the given period began (yesterday for day, the day before this week's start
    /// for week). On the first day/week of the month this collapses to an empty range, matching
    /// the $0 "earlier" figure the breakdown shows.
    private func monthBeforePeriodDateRange(for period: HeroPeriod) -> (start: String, end: String) {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = cal.timeZone

        let monthStart = cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
        let periodStart: Date
        switch period {
        case .day:
            periodStart = cal.startOfDay(for: now)
        case .week:
            periodStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        case .month:
            periodStart = monthStart
        }
        let end = cal.date(byAdding: .day, value: -1, to: periodStart) ?? monthStart
        return (fmt.string(from: monthStart), fmt.string(from: end))
    }

    private func formatDisplayDate(_ dateStr: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = Calendar.bablo.timeZone
        guard let date = parser.date(from: dateStr) else { return dateStr }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = Calendar.bablo.timeZone
        return formatter.string(from: date)
    }

    private func periodSpendListTitle(for period: HeroPeriod) -> String {
        switch period {
        case .day:   return "Spent today"
        case .week:  return "Spent this week"
        case .month: return "Spent this month"
        }
    }

    private func checkNetworkStatus() {
        networkMonitor?.cancel()
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
        networkMonitor = monitor
    }
    
    private func checkConnectivityAndRefresh(forceRefresh: Bool = true) {
        Task {
            if !isOffline || forceRefresh {
                isRefreshing = true
                
                do {
                    // Refresh both accounts and transactions
                    try await accountsService.refreshAccounts(forceRefresh: forceRefresh)
                    try? await budgetService.fetchTotalBalance()
                    try? await transactionsService.fetchRecentTransactions(forceRefresh: forceRefresh, limit: 20)
                    // Coach is a slow Gemini round-trip — fire it off without blocking the
                    // streak / Coming-up widgets. The card appears on its own once it loads.
                    Task { _ = try? await coachService.fetchCoachInsights() }
                    await refreshStreakIfBankLinked()
                    try? await subService.fetchSubscriptions()
                    await subService.scanIdleSubscriptions()
                } catch {
                    Logger.e("Failed to refresh data: \(error)")
                }
                
                isRefreshing = false
            }
        }
    }

    private func loadCushionSheetData() async {
        let period = heroPeriod.pulsePeriod
        let tracked = trackedCategories
        let windows = cushionWindows(for: period)

        await pulseService.fetchCushionData(
            currentStart: windows.currentStart,
            currentEnd: windows.currentEnd,
            previousStart: windows.previousStart,
            previousEnd: windows.previousEnd,
            trackedCategories: tracked
        )
    }

    /// Current + aligned-previous windows for the Cushion sheet. The previous window is clamped to
    /// the same elapsed length as the current one (June 1 vs May 1), so drivers and pace compare
    /// like-for-like rather than partial-current vs full-prior-period.
    private func cushionWindows(for period: PulsePeriod) -> (currentStart: String, currentEnd: String, previousStart: String, previousEnd: String) {
        let cal = Calendar.bablo
        let now = Date()
        let ranges = PreviousPeriodDateRange.compute(calendar: cal)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now

        switch period {
        case .month:
            return (fmt.string(from: currentMonthStart), ranges.todayDate, ranges.prevMonthStart, ranges.prevMonthSameDayEnd)
        case .week:
            return (ranges.currentWeekStart, ranges.todayDate, ranges.prevWeekStart, ranges.prevWeekSameDayEnd)
        case .day:
            return (ranges.todayDate, ranges.todayDate, ranges.yesterdayDate, ranges.yesterdayDate)
        }
    }

    /// Lightweight foreground refresh: just the Recent feed (and the balance it pairs with),
    /// so activity that synced while the app was backgrounded shows up without a manual
    /// pull-to-refresh. Deliberately skips the full accounts/subscriptions/coach refresh to
    /// avoid churn on every foreground.
    private func refreshRecentTransactionsOnForeground() async {
        guard !isOffline else { return }
        try? await transactionsService.fetchRecentTransactions(forceRefresh: true, limit: 20)
        try? await budgetService.fetchTotalBalance()
    }

    private func refreshHomeForCurrentUser() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await userAccount.fetchProfile()
        await budgetService.fetchBudgetSummary()
        // Pull the single-pool RPC row so the Hero reflects goals_set_aside (Mode B
        // auto-stash) and the pool that nets it; the Hero prefers this over the
        // synthesized fallback whenever it's loaded.
        await budgetService.fetchBudgetState(incomeBasis: userAccount.incomeBasis)
        try? await budgetService.fetchTotalBalance()

        if !isOffline {
            do {
                try await accountsService.refreshAccounts(forceRefresh: true)
                try? await budgetService.fetchTotalBalance()
                try? await transactionsService.fetchRecentTransactions(forceRefresh: true, limit: 20)
                // Coach is a slow Gemini round-trip — fire it off without blocking the
                // streak / Coming-up widgets. The card appears on its own once it loads.
                Task { _ = try? await coachService.fetchCoachInsights() }
                await refreshStreakIfBankLinked()
                try? await subService.fetchSubscriptions()
                await subService.scanIdleSubscriptions()
            } catch {
                Logger.e("Failed to refresh data: \(error)")
            }
        } else {
            // Offline fallback: load cached streaks/subscriptions
            await refreshStreakIfBankLinked()
            try? await subService.fetchSubscriptions()
            await subService.scanIdleSubscriptions()
        }
    }

    private func refreshStreakIfBankLinked() async {
        guard !accountsService.visibleBanksWithAccounts.isEmpty else {
            streakService.clearStreak()
            return
        }

        try? await streakService.fetchUserStreak()
    }
}

private extension HeroPeriod {
    var pulsePeriod: PulsePeriod {
        switch self {
        case .day:   return .day
        case .week:  return .week
        case .month: return .month
        }
    }
}

#if DEBUG

#Preview("Home · Normal") {
    HomeViewPreviewHost(theme: .normal)
}

#Preview("Home · Pop") {
    HomeViewPreviewHost(theme: .pop)
}

private struct HomeViewPreviewHost: View {
    let theme: BabloTheme

    private let userAccount = HomeViewPreviewFixtures.userAccount()
    private let accountsService = HomeViewPreviewFixtures.accountsService()
    private let transactionsService = HomeViewPreviewFixtures.transactionsService()
    private let budgetService = HomeViewPreviewFixtures.budgetService()
    private let coachService = HomeViewPreviewFixtures.coachService()
    private let streakService = HomeViewPreviewFixtures.streakService()
    private let subService = HomeViewPreviewFixtures.subscriptionsService()
    private let pulseService = PulseService()
    private let homeBreakdownService = HomeBreakdownService()
    private let navigationState = NavigationState()

    var body: some View {
        NavigationStack(path: navigationPath) {
            HomeView(loadsData: false)
                .environmentObject(accountsService)
                .environmentObject(transactionsService)
                .environmentObject(budgetService)
                .environmentObject(userAccount)
                .environmentObject(navigationState)
                .environmentObject(coachService)
                .environmentObject(streakService)
                .environmentObject(subService)
                .environmentObject(pulseService)
                .environmentObject(homeBreakdownService)
                .babloTheme(theme)
        }
    }

    private var navigationPath: Binding<NavigationPath> {
        Binding(
            get: { navigationState.homeNavPath },
            set: { navigationState.homeNavPath = $0 }
        )
    }
}

@MainActor
private enum HomeViewPreviewFixtures {
    static func userAccount() -> UserAccount {
        let account = UserAccount()
        account.currentUser = User(id: "preview-user", name: "Mia", token: "", email: "mia@example.com")
        account.isSignedIn = true
        account.spendingPlanMode = .monthlyPlan
        account.incomeBasis = .projected
        return account
    }

    static func accountsService() -> AccountsService {
        let service = AccountsService()
        service.banksWithAccounts = [
            Bank(
                id: 1,
                bank_name: "Chase",
                logo: nil,
                primary_color: "#005EB8",
                url: nil,
                accounts: [
                    BankAccount(
                        id: 1,
                        item_id: 1,
                        name: "Everyday Checking",
                        mask: "3382",
                        official_name: "Chase Total Checking",
                        current_balance: 1_920,
                        available_balance: 1_875,
                        _type: "depository",
                        subtype: "checking",
                        hidden: false,
                        iso_currency_code: "USD",
                        updated_at: nil
                    ),
                    BankAccount(
                        id: 2,
                        item_id: 1,
                        name: "Freedom Card",
                        mask: "1188",
                        official_name: "Chase Freedom",
                        current_balance: 420,
                        available_balance: nil,
                        _type: "credit",
                        subtype: "credit card",
                        hidden: false,
                        iso_currency_code: "USD",
                        updated_at: nil
                    )
                ]
            )
        ]
        return service
    }

    static func budgetService() -> BudgetService {
        let service = BudgetService()
        service.totalBalance = TotalBalance(balance: 1_500, asOf: "2026-06-06", iso_currency_code: "USD")
        service.monthlyIncome = 5_400
        service.monthlyMandatoryExpenses = 2_250
        service.knownIncomeThisMonth = 5_400
        service.extraIncomeThisMonth = 120
        service.variableSpend = 980
        service.currentWeekVariableSpend = 218
        service.todayVariableSpend = 38
        service.previousDayVariableSpend = 54
        service.previousWeekVariableSpend = 305
        service.previousMonthVariableSpend = 1_360
        return service
    }

    static func transactionsService() -> TransactionsService {
        let service = TransactionsService()
        service.transactions = [
            transaction(id: 1, amount: 18.42, date: "2026-06-06", name: "Blue Bottle Coffee", merchant: "Blue Bottle", primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_COFFEE", isSpend: true, isIncome: false),
            transaction(id: 2, amount: 64.18, date: "2026-06-05", name: "Trader Joe's", merchant: "Trader Joe's", primary: "GENERAL_MERCHANDISE", detailed: "GENERAL_MERCHANDISE_SUPERSTORES", isSpend: true, isIncome: false),
            transaction(id: 3, amount: -2_850, date: "2026-06-05", name: "Payroll Deposit", merchant: nil, primary: "INCOME", detailed: "INCOME_WAGES", isSpend: false, isIncome: true),
            transaction(id: 4, amount: 32.70, date: "2026-06-04", name: "Lyft", merchant: "Lyft", primary: "TRANSPORTATION", detailed: "TRANSPORTATION_TAXIS_AND_RIDE_SHARES", isSpend: true, isIncome: false),
            transaction(id: 5, amount: 84.12, date: "2026-06-03", name: "Amazon Marketplace", merchant: "Amazon", primary: "GENERAL_MERCHANDISE", detailed: "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES", isSpend: true, isIncome: false)
        ]
        return service
    }

    static func coachService() -> CoachService {
        let service = CoachService()
        service.currentInsight = CoachInsight(
            badge: "COACH - TODAY",
            headline: "Eats are warming up",
            nudgeText: "Coffee and takeout are pacing ahead of last week. Skip two small buys and the cushion gets roomier.",
            actionLabel: "Review eats",
            alternativeTip: "One grocery run beats three tiny convenience stops."
        )
        return service
    }

    static func streakService() -> StreakService {
        let service = StreakService()
        service.userStreak = UserStreak(
            currentStreak: 7,
            maxStreak: 12,
            last28DaysStatus: [true, true, false, true, true, true, true, false, true, true] + Array(repeating: false, count: 18)
        )
        return service
    }

    static func subscriptionsService() -> SubscriptionsService {
        let service = SubscriptionsService()
        let streams = recurringStreams()
        service.allRecurringStreams = streams
        service.subscriptions = streams.filter { stream in
            ["Spotify", "Netflix", "Canva"].contains(stream.merchantName ?? stream.description)
        }
        service.idleCount = 1
        service.idleSubscriptionIDs = [3]
        return service
    }

    private static func recurringStreams() -> [RecurringStream] {
        [
            recurringStream(id: 1, name: "Spotify", category: "ENTERTAINMENT", amount: 11.99, daysUntilDue: 2),
            recurringStream(id: 2, name: "Rent", category: "RENT_OR_MORTGAGE", amount: 1_450, daysUntilDue: 6),
            recurringStream(id: 3, name: "Canva", category: "GENERAL_SERVICES", amount: 12.85, daysUntilDue: 8),
            recurringStream(id: 4, name: "Verizon", category: "UTILITIES", amount: 65, daysUntilDue: 10)
        ]
    }

    private static func recurringStream(id: Int, name: String, category: String, amount: Double, daysUntilDue: Int) -> RecurringStream {
        let cal = Calendar.bablo
        let dueDate = cal.date(byAdding: .day, value: daysUntilDue, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone

        return RecurringStream(
            id: id,
            plaidStreamId: "preview_stream_\(id)",
            description: name,
            merchantName: name,
            personalFinanceCategory: category,
            personalFinanceSubcategory: nil,
            frequency: "MONTHLY",
            averageAmount: amount,
            monthlyAmount: amount,
            isoCurrencyCode: "USD",
            type: "expense",
            status: "MATURE",
            isActive: true,
            firstDate: nil,
            lastDate: nil,
            predictedNextDate: fmt.string(from: dueDate),
            isUserModified: false,
            userMarkedRecurring: nil,
            isExcluded: false,
            isManual: false,
            matchPattern: nil,
            accountId: nil
        )
    }

    private static func transaction(
        id: Int,
        amount: Double,
        date: String,
        name: String,
        merchant: String?,
        primary: String,
        detailed: String,
        isSpend: Bool,
        isIncome: Bool
    ) -> Transaction {
        Transaction(
            id: id,
            account_id: 1,
            amount: amount,
            date: date,
            authorized_date: date,
            name: name,
            merchant_name: merchant,
            pending: false,
            category: nil,
            transaction_id: "preview_home_tx_\(id)",
            pending_transaction_transaction_id: nil,
            iso_currency_code: "USD",
            payment_channel: "in store",
            user_id: "preview-user",
            logo_url: nil,
            website: nil,
            personal_finance_category: primary,
            personal_finance_subcategory: detailed,
            created_at: nil,
            updated_at: nil,
            is_spend: isSpend,
            is_income: isIncome
        )
    }
}

#endif
