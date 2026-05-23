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
    @State private var isOffline = false
    @State private var isRefreshing = false
    @State private var showingOnboarding = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionSpacing) {
                if isRefreshing {
                    ProgressView()
                        .tint(ColorPalette.primary)
                }

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
                
                // Only show charts if we have accounts OR budget data
                if !accountsService.banksWithAccounts.isEmpty || budgetService.totalBalance?.balance != 0 {
                    VStack(spacing: Spacing.sm) {
                        // 1. Original Hero: Total Balance (Carousel) - Restored to top
                        HeroCarouselView()
                            .environmentObject(budgetService)
                            .padding(.top, Dimensions.topSpacingReduction)

                        // 2. New Secondary Hero: Variable Spending / "Spend Money"
                        VariableSpendingView()

                        // 3. Budget Summary Card
                        HeroCardView(model: HeroCardViewModel(
                            title: "Monthly Budget",
                            amount: budgetService.variableBudget,
                            monthlyChange: budgetService.variableBudget - (budgetService.monthlyIncome - budgetService.monthlyMandatoryExpenses),
                            isPositive: budgetService.variableBudget >= 0,
                            currencyCode: "USD",
                            overrideStatusText: budgetService.variableBudget >= 0 ? "Left to Spend" : "Over Budget"
                        ))
                    }
                }

                // Show empty state IF no accounts linked
                if accountsService.banksWithAccounts.isEmpty {
                    HeroBudgetEmptyStateView()
                        .onTapGesture {
                            showingOnboarding = true
                        }
                        .padding(.top, Spacing.xl)
                }

                RecentTransactionsView()
                    .padding(.top, Spacing.sm)
                Spacer()                    
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
        .navigationDestination(for: Bank.self) { bank in
            BankDetailView(bank: bank)
        }
        .navigationDestination(for: BankAccount.self) { account in
            BankAccountDetailView(account: account)
        }
        .onAppear {
            // Check network status when view appears
            checkNetworkStatus()
        }
    }
    
    private func checkNetworkStatus() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    private func checkConnectivityAndRefresh(forceRefresh: Bool = true) {
        Task {
            if !isOffline || forceRefresh {
                isRefreshing = true
                
                do {
                    // Refresh both accounts and transactions
                    try await accountsService.refreshAccounts(forceRefresh: forceRefresh)
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

        if !isOffline {
            do {
                try await accountsService.refreshAccounts(forceRefresh: true)
            } catch {
                Logger.e("Failed to refresh data: \(error)")
            }
        }
    }
}
