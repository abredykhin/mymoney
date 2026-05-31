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
    @State private var isOffline = false
    @State private var isRefreshing = false
    @State private var showingOnboarding = false
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
