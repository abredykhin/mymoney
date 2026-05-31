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
                    breakdown: pulseService.categoryBreakdown ?? [],
                    dailyEnergy: pulseService.dailyEnergy,
                    isLoading: pulseService.isLoadingBreakdown || pulseService.isLoadingDailyEnergy,
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
            daysElapsedInWeek: daysElapsedInWeek
        )
    }

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
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
                    try? await transactionsService.fetchRecentTransactions(forceRefresh: forceRefresh, limit: 5)
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
        let current = period.currentWindow
        let comparison = period.comparisonWindow
        let tracked = trackedCategories
        let energyWindow: PulseDateWindow
        switch period {
        case .month:
            energyWindow = monthlyEnergyWindow
        case .week:
            energyWindow = weeklyEnergyWindow
        case .day:
            energyWindow = current
        }

        async let breakdown: Void = {
            do {
                try await pulseService.fetchCategoryBreakdown(
                    startDate: current.startDate,
                    endDate: current.endDate,
                    comparisonStartDate: comparison?.startDate,
                    comparisonEndDate: comparison?.endDate,
                    trackedCategories: tracked
                )
            } catch {
                // PulseService owns the published error state.
            }
        }()

        async let energy: Void = {
            await pulseService.fetchDailyEnergy(startDate: energyWindow.startDate, endDate: energyWindow.endDate)
        }()

        _ = await (breakdown, energy)
    }

    private var weeklyEnergyWindow: PulseDateWindow {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let start = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
        return PulseDateWindow(startDate: fmt.string(from: start), endDate: fmt.string(from: now))
    }

    private var monthlyEnergyWindow: PulseDateWindow {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
        let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
        return PulseDateWindow(startDate: fmt.string(from: start), endDate: fmt.string(from: now))
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
                try? await transactionsService.fetchRecentTransactions(forceRefresh: true, limit: 5)
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
