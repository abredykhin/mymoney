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
    @State private var isOffline = false
    @State private var isRefreshing = false
    @State private var showingOnboarding = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.sectionSpacing) {
                HomeTopBarView()
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.sm)
                
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
                
                let hasBudgetData = budgetService.monthlyIncome > 0 || budgetService.monthlyMandatoryExpenses > 0
                let hasBankAccounts = !accountsService.banksWithAccounts.isEmpty

                // Show hero section when budget data exists OR bank is linked
                if hasBudgetData || hasBankAccounts {
                    VStack(spacing: Spacing.sm) {
                        // 1. Liquid spendable hero — primary widget
                        LiquidHeroView()
                            .environmentObject(budgetService)
                            .padding(.horizontal, Spacing.screenEdge)
                            .padding(.top, Dimensions.topSpacingReduction)
                    }
                }

                // 2b. AI Coach Card — only when bank accounts linked, recommendation is loaded, and not dismissed
                if !accountsService.banksWithAccounts.isEmpty && coachService.currentInsight != nil && !coachService.isDismissed {
                    CoachCardView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }

                // Empty state only when no budget data and no bank accounts
                if !hasBudgetData && !hasBankAccounts {
                    HeroBudgetEmptyStateView()
                        .onTapGesture {
                            showingOnboarding = true
                        }
                        .padding(.top, Spacing.xl)
                }

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
                    if !accountsService.banksWithAccounts.isEmpty {
                        _ = try? await coachService.fetchCoachInsights()
                    }
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

        if !isOffline {
            do {
                try await accountsService.refreshAccounts(forceRefresh: true)
                if !accountsService.banksWithAccounts.isEmpty {
                    _ = try? await coachService.fetchCoachInsights()
                }
            } catch {
                Logger.e("Failed to refresh data: \(error)")
            }
        }
    }
}
