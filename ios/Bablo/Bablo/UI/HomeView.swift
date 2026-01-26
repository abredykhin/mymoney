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

                        // 2. New Secondary Hero: Discretionary Spending / "Spend Money"
                        DiscretionaryHeroView()

                        // 3. Budget Summary Card
                        HeroCardView(model: HeroCardViewModel(
                            title: "Monthly Budget",
                            amount: budgetService.discretionaryBudget,
                            monthlyChange: budgetService.discretionaryBudget - (budgetService.monthlyIncome - budgetService.monthlyMandatoryExpenses),
                            isPositive: budgetService.discretionaryBudget >= 0,
                            currencyCode: "USD",
                            overrideStatusText: budgetService.discretionaryBudget >= 0 ? "Left to Spend" : "Over Budget"
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
        .task {
            checkConnectivityAndRefresh(forceRefresh: false)
            await UserAccount.shared.fetchProfile()
            await budgetService.checkAndTriggerBudgetAnalysis()
            
            // Auto-trigger onboarding if new user (no accounts, no cache)
            if accountsService.banksWithAccounts.isEmpty && !showingOnboarding {
                // Check if we should auto-prompt (simple heuristic: if no accounts loaded after refresh)
                try? await Task.sleep(nanoseconds: 500_000_000) // Small delay to allow refresh to complete
                if accountsService.banksWithAccounts.isEmpty {
                    showingOnboarding = true
                }
            }
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
}
