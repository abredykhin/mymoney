//
//  TransactionsListView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/23/25.
//

import SwiftUI

// MARK: - Transactions List (Extracted)

struct TransactionsListView: View {
    @EnvironmentObject var accountsService: AccountsService
    
    let transactions: [Transaction]
    let groupedByMonth: [AllTransactionsView.MonthKey: [AllTransactionsView.DayKey: [Transaction]]]
    let sortedMonths: [AllTransactionsView.MonthKey]
    let monthlyStats: [Int: [Int: AllTransactionsView.Summary]]
    let dailyStats: [String: AllTransactionsView.Summary]
    let isLoadingStats: Bool
    let isLoadingMore: Bool
    let loadingError: Error?
    let hasMore: Bool
    let loadMoreThresholdIndex: Int
    let refreshAction: () async -> Void
    let loadMoreAction: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Month Sections
                ForEach(sortedMonths, id: \.self) { month in
                    Section {
                        // Day Sections
                        ForEach(sortedDays(for: month), id: \.self) { day in
                            Section {
                                // Transactions
                                ForEach(groupedByMonth[month]?[day] ?? [], id: \.id) { transaction in
                                    TransactionView(transaction: transaction)
                                        .padding(.horizontal, 0) // Remove default list padding
                                        .onAppear {
                                            checkPreload(for: transaction)
                                        }
                                }
                            } header: {
                                DayHeaderView(day: day, summary: dailySummary(for: month, day: day))
                                    .background(ColorPalette.backgroundPrimary) // Ensure header has background for sticky effect
                            }
                        }
                    } header: {
                        MonthHeaderView(month: month, summary: monthlySummary(for: month))
                            .background(ColorPalette.backgroundPrimary) // Ensure header has background for sticky effect
                    }
                }
                
                // Bottom Indicators
                if isLoadingMore {
                    bottomLoadingIndicator
                } else if loadingError != nil && hasMore {
                    bottomErrorIndicator
                }
                
                // Add some bottom padding for safe area
                Color.clear.frame(height: Spacing.xl)
            }
        }
        .refreshable {
            await refreshAction()
        }
        .background(ColorPalette.backgroundPrimary)
    }
    
    // MARK: - Helpers
    
    private func sortedDays(for month: AllTransactionsView.MonthKey) -> [AllTransactionsView.DayKey] {
        groupedByMonth[month]?.keys.sorted(by: >) ?? []
    }
    
    private func checkPreload(for transaction: Transaction) {
        if let originalIndex = transactions.firstIndex(where: { $0.id == transaction.id }),
           originalIndex >= loadMoreThresholdIndex && hasMore && !isLoadingMore {
            loadMoreAction()
        }
    }
    
    // Summary Helpers
    private func monthlySummary(for month: AllTransactionsView.MonthKey) -> AllTransactionsView.Summary? {
        // Try to get from server stats
        if let stats = monthlyStats[month.year]?[month.month] { return stats }

        // If still loading, show loading indicator
        if isLoadingStats { return nil }

        // Stats loaded (or failed to load) but month not found - return zeros
        return AllTransactionsView.Summary(totalIn: 0, totalOut: 0)
    }

    private func dailySummary(for month: AllTransactionsView.MonthKey, day: AllTransactionsView.DayKey) -> AllTransactionsView.Summary? {
        let dateString = AllTransactionsView.dateFormatter.string(from: day.date)

        // Try to get from server stats
        if let stats = dailyStats[dateString] { return stats }

        // If still loading, show loading indicator
        if isLoadingStats { return nil }

        // Stats loaded (or failed to load) but day not found - return zeros
        return AllTransactionsView.Summary(totalIn: 0, totalOut: 0)
    }
    
    private func processTransaction(_ transaction: Transaction, totalIn: inout Double, totalOut: inout Double) {
        if transaction.isTransfer { return }
        
        let accountType = getAccountType(for: transaction.account_id)?.lowercased() ?? "depository"
        
        if transaction.amount > 0 {
             totalOut += transaction.amount
        } else {
            let amount = abs(transaction.amount)
            if accountType == "depository" || accountType == "investment" {
                totalIn += amount
            }
        }
    }
    
    private func getAccountType(for accountId: Int) -> String? {
        for bank in accountsService.banksWithAccounts {
            if let account = bank.accounts.first(where: { $0.id == accountId }) {
                return account.type
            }
        }
        return nil
    }

    private var bottomLoadingIndicator: some View {
        HStack {
            Spacer(); ProgressView().tint(ColorPalette.primary); Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, Spacing.lg)
    }
    
    private var bottomErrorIndicator: some View {
        HStack {
            Spacer()
            VStack {
                Text("Couldn't load more").font(Typography.footnote).foregroundColor(ColorPalette.textSecondary)
                Button("Retry") { loadMoreAction() }.font(Typography.footnote)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, Spacing.lg)
    }
}
