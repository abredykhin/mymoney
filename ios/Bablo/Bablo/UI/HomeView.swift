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
                let hasBankAccounts = !accountsService.banksWithAccounts.isEmpty

                let shouldShowMoneyWidgets = hasBudgetData || hasBankAccounts || !transactionsService.transactions.isEmpty

                if hasBudgetData || hasBankAccounts {
                    LiquidHeroView(period: $heroPeriod, onTap: {
                        navigationState.homeNavPath.append(
                            HomeDestination.budgetBreakdown(heroPeriod)
                        )
                    }, onDeltaTap: {
                        showingCushionSheet = true
                        Task { await loadCushionSheetData() }
                    })
                    .environmentObject(budgetService)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.md)
                }

                if !accountsService.banksWithAccounts.isEmpty && coachService.currentInsight != nil && !coachService.isDismissed {
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
            case .breakdownTransactions(let source, let period, let categoryName):
                BreakdownTransactionListView(source: source, period: period, categoryFilter: categoryName)
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
                    initialFilter: .out
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
                .presentationDragIndicator(Visibility.visible)
            }
        }
        .refreshable {
            checkConnectivityAndRefresh()
        }
        .task(id: userAccount.currentUser?.id) {
            await refreshHomeForCurrentUser()
        }
        .onChange(of: scenePhase) { _, newPhase in
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
            checkNetworkStatus()
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
            upcomingUnpaidExpenses: budgetService.upcomingUnpaidBills,
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
                    _ = try? await coachService.fetchCoachInsights()
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
        try? await budgetService.fetchTotalBalance()

        if !isOffline {
            do {
                try await accountsService.refreshAccounts(forceRefresh: true)
                try? await budgetService.fetchTotalBalance()
                try? await transactionsService.fetchRecentTransactions(forceRefresh: true, limit: 20)
                _ = try? await coachService.fetchCoachInsights()
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
        guard !accountsService.banksWithAccounts.isEmpty else {
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
