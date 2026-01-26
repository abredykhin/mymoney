//
//  AllTransactionsView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/24/25.
//

import SwiftUI

struct AllTransactionsView: View {
    @EnvironmentObject private var transactionsService: TransactionsService
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var navigationState: NavigationState

    @EnvironmentObject var accountsService: AccountsService // Injected to access account types

    @State private var isLoadingMore = false // Keep for bottom indicator logic
    @State private var loadingError: Error?
    
    // Stats State
    @State private var monthlyStats: [Int: [Int: AllTransactionsView.Summary]] = [:] // Year -> Month -> Summary
    @State private var dailyStats: [String: AllTransactionsView.Summary] = [:] // DateString -> Summary
    @State private var isLoadingStats = false
    
    struct MonthKey: Hashable, Comparable {
        let year: Int
        let month: Int

        static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
            if lhs.year != rhs.year {
                return lhs.year < rhs.year
            }
            return lhs.month < rhs.month
        }
    }

    struct DayKey: Hashable, Comparable {
        let date: Date

        static func < (lhs: DayKey, rhs: DayKey) -> Bool {
            lhs.date < rhs.date
        }
    }
    
    struct Summary {
        let totalIn: Double
        let totalOut: Double
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Use UTC for date-only strings to avoid timezone conversion issues
        // Database stores DATE type (no time), so we parse as UTC to keep dates consistent
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // Group transactions by month, then by day
    private var groupedByMonth: [MonthKey: [DayKey: [Transaction]]] {
        // Use UTC calendar to match UTC date parsing
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var result: [MonthKey: [DayKey: [Transaction]]] = [:]

        for transaction in transactionsService.transactions {
            // Use authorized_date if available, otherwise fall back to date
            // This matches what TransactionView displays
            let dateString = transaction.authorized_date ?? transaction.date
            let dateFromString = AllTransactionsView.dateFormatter.date(from: dateString)
            let validDate = dateFromString ?? Date.distantPast

            let year = calendar.component(.year, from: validDate)
            let month = calendar.component(.month, from: validDate)
            let monthKey = MonthKey(year: year, month: month)

            let dayStart = calendar.startOfDay(for: validDate)
            let dayKey = DayKey(date: dayStart)

            if result[monthKey] == nil {
                result[monthKey] = [:]
            }
            if result[monthKey]![dayKey] == nil {
                result[monthKey]![dayKey] = []
            }
            result[monthKey]![dayKey]!.append(transaction)
        }

        return result
    }

    // Sort month keys (newest first)
    private var sortedMonths: [MonthKey] {
        groupedByMonth.keys.sorted(by: >)
    }

    // Computed index to trigger load more (based on the original flat list)
    var loadMoreThresholdIndex: Int {
        guard !transactionsService.transactions.isEmpty else { return 0 }
        // Trigger loading when about 5 items are left
        return max(0, transactionsService.transactions.count - 5)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Initial loading indicator (full screen)
                if transactionsService.isLoading && transactionsService.transactions.isEmpty && !isLoadingMore {
                    ProgressView()
                        .tint(ColorPalette.primary)
                        .frame(maxHeight: .infinity)
                } else if !transactionsService.transactions.isEmpty {
                    TransactionsListView(
                        transactions: transactionsService.transactions,
                        groupedByMonth: groupedByMonth,
                        sortedMonths: sortedMonths,
                        monthlyStats: monthlyStats,
                        dailyStats: dailyStats,
                        isLoadingStats: isLoadingStats,
                        isLoadingMore: isLoadingMore,
                        loadingError: loadingError,
                        hasMore: transactionsService.paginationInfo?.hasMore ?? false,
                        loadMoreThresholdIndex: loadMoreThresholdIndex,
                        refreshAction: refreshTransactions,
                        loadMoreAction: loadMoreTransactions
                    )
                } else if !transactionsService.isLoading { // Empty state
                    EmptyTransactionsView {
                        await refreshTransactions()
                    }
                }
            }
        }
        .navigationDestination(for: Bank.self) { bank in
            BankDetailView(bank: bank)
        }
        .navigationDestination(for: BankAccount.self) { account in
            BankAccountDetailView(account: account)
        }
        .task {
            if transactionsService.transactions.isEmpty {
                await refreshTransactions()
            } else {
                if monthlyStats.isEmpty {
                    await fetchStats()
                }
            }
        }
    }
    

    
    
    // MARK: - Subviews extraction
    
    private func refreshTransactions() async {
        loadingError = nil // Clear previous errors on refresh
        isLoadingMore = false // Ensure bottom indicator isn't stuck
        
        // Parallel fetch: transactions + stats
        // We do this concurrently for performance
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    try await transactionsService.fetchRecentTransactions(forceRefresh: true, loadMore: false)
                } catch {
                    Logger.e("Failed to refresh transactions: \(error)")
                    // We don't set loadingError here because it's handled in the UI state
                }
            }
            
            group.addTask {
                await fetchStats()
            }
        }
    }
    
    private func fetchStats() async {
        guard !isLoadingStats else { return }
        isLoadingStats = true

        // Define range for stats (last 1 year to avoid excessive memory usage)
        // This covers most typical use cases while preventing memory issues
        // Use UTC calendar for consistency with date parsing
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let endDate = Date()
        let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? Date.distantPast

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        do {
            async let monthly = transactionsService.fetchMonthlyStats(startDate: startStr, endDate: endStr)
            async let daily = transactionsService.fetchDailyStats(startDate: startStr, endDate: endStr)
            
            let (monthlyData, dailyData) = try await (monthly, daily)
            
            // Update UI state
            var newMonthlyStats: [Int: [Int: AllTransactionsView.Summary]] = [:]
            for stat in monthlyData {
                let year = Int(stat.year)
                let month = Int(stat.month)
                if newMonthlyStats[year] == nil {
                    newMonthlyStats[year] = [:]
                }
                newMonthlyStats[year]![month] = Summary(totalIn: stat.totalIn, totalOut: stat.totalOut)
            }
            self.monthlyStats = newMonthlyStats
            
            var newDailyStats: [String: AllTransactionsView.Summary] = [:]
            for stat in dailyData {
                // Ensure date string format consistency
                // If RPC returns YYYY-MM-DD, we use it directly
                // (Our dateFormatter is YYYY-MM-DD)
                newDailyStats[stat.date] = Summary(totalIn: stat.totalIn, totalOut: stat.totalOut)
            }
            self.dailyStats = newDailyStats
            
            Logger.i("AllTransactionsView: Successfully loaded stats")
        } catch {
            Logger.e("AllTransactionsView: Failed to load stats: \(error)")
        }
        
        isLoadingStats = false
    }
    
    private func preloadNextPage() {
        if (transactionsService.paginationInfo?.hasMore ?? false) && !isLoadingMore && !transactionsService.isLoading {
            loadMoreTransactions()
        }
    }
    
    private func loadMoreTransactions() {
        // Prevent multiple simultaneous loads
        guard !isLoadingMore && !transactionsService.isLoading && (transactionsService.paginationInfo?.hasMore ?? false) else {
            return
        }

        // Memory safety: Stop loading after 500 transactions (about 10 pages)
        // This prevents excessive memory usage on devices that have been idle/locked
        guard transactionsService.transactions.count < 500 else {
            Logger.w("AllTransactionsView: Reached transaction limit (500) to prevent memory issues")
            return
        }

        Task {
            self.loadingError = nil
            self.isLoadingMore = true

            do {
                try await transactionsService.fetchRecentTransactions(forceRefresh: false, loadMore: true)
            } catch {
                Logger.e("Failed to load more transactions: \(error)")
                self.loadingError = error
            }

            self.isLoadingMore = false
        }
    }
    
    // Calculate summary for a month (fetching from server stats)
    private func monthlySummary(for month: MonthKey) -> Summary? {
        // Try to get from server stats first
        if let stats = monthlyStats[month.year]?[month.month] {
            return stats
        }

        // If stats are still loading, return nil to show loading indicator
        // This prevents showing incorrect partial totals from paginated data
        if isLoadingStats {
            return nil
        }

        // At this point, stats have loaded (or failed to load)
        // Return zeros for months not found in stats
        return Summary(totalIn: 0, totalOut: 0)
    }

    // Calculate summary for a specific day (fetching from server stats)
    private func dailySummary(for month: MonthKey, day: DayKey) -> Summary? {
        let dateString = AllTransactionsView.dateFormatter.string(from: day.date)

        // Try to get from server stats
        if let stats = dailyStats[dateString] {
            return stats
        }

        // If loading stats, return nil
        if isLoadingStats {
            return nil
        }

        // At this point, stats have loaded (or failed to load)
        // Return zeros for days not found in stats
        return Summary(totalIn: 0, totalOut: 0)
    }
    
    // Get sorted days for a month (newest first)
    private func sortedDays(for month: MonthKey) -> [DayKey] {
        guard let days = groupedByMonth[month] else { return [] }
        return days.keys.sorted(by: >)
    }
}

#Preview {
    let transactionService: TransactionsService = {
        let s = TransactionsService()
        s.transactions = [
            TransactionView_Previews.foodTransaction,
            TransactionView_Previews.travelTransaction,
            TransactionView_Previews.incomeTransaction,
            Transaction(
               id: 4,
               account_id: 0,
               amount: 50.00,
               date: "2024-11-20", // Different month to show month header
               authorized_date: "2024-11-20",
               name: "Previous Month Item",
               merchant_name: "Previous Month Item",
               pending: false,
               category: ["Shopping"],
               transaction_id: "4",
               pending_transaction_transaction_id: nil,
               iso_currency_code: "USD",
               payment_channel: "online",
               user_id: nil,
               logo_url: nil,
               website: nil,
               personal_finance_category: "SHOPPING",
               personal_finance_subcategory: nil,
               created_at: nil,
               updated_at: nil
           )
        ]
        s.isLoading = false
        return s
    }()
    
    // Attempt to set stats if accessible, otherwise preview will just lack stats
    
    let userAccount = UserAccount()
    let navigationState = NavigationState()
    let accountsService = AccountsService()
    
    AllTransactionsView()
        .environmentObject(transactionService)
        .environmentObject(userAccount)
        .environmentObject(navigationState)
        .environmentObject(accountsService)
        .background(ColorPalette.backgroundPrimary)
}
