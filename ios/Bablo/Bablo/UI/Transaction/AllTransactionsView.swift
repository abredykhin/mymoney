//
//  AllTransactionsView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/24/25.
//

import SwiftUI

struct AllTransactionsView: View {
    @StateObject private var transactionsService = TransactionsService()
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var navigationState: NavigationState

    @EnvironmentObject var accountsService: AccountsService // Injected to access account types

    @State private var showingProfile = false
    @State private var isLoadingMore = false // Keep for bottom indicator logic
    @State private var loadingError: Error?
    
    // Stats State
    @State private var monthlyStats: [Int: [Int: AllTransactionsView.Summary]] = [:] // Year -> Month -> Summary
    @State private var dailyStats: [String: AllTransactionsView.Summary] = [:] // DateString -> Summary
    @State private var isLoadingStats = false
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Use UTC for date-only strings to avoid timezone conversion issues
        // Database stores DATE type (no time), so we parse as UTC to keep dates consistent
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
    
    // MARK: - Data Structures for Grouping

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

    // Get sorted days for a month (newest first)
    private func sortedDays(for month: MonthKey) -> [DayKey] {
        guard let days = groupedByMonth[month] else { return [] }
        return days.keys.sorted(by: >)
    }

    // MARK: - Summary Calculations

    struct Summary {
        let totalIn: Double
        let totalOut: Double
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
                        .tint(.accentColor)
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
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingProfile = true
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView { ProfileView() }
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
}

// MARK: - Subviews

struct EmptyTransactionsView: View {
    let refreshAction: () async -> Void
    
    var body: some View {
        ZStack {
            ScrollView {
                // Empty view to allow pull-to-refresh
                Color.clear
                    .frame(height: 1) // Minimal height to ensure scrollability?
                    // Actually EmptyView in ScrollView might not be scrollable if content is 0.
                    // Better to put a wrapper.
            }
            .refreshable {
                await refreshAction()
            }
            
            VStack {
                Text("No transactions found")
                    .font(.headline)
                Text("Pull to refresh")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct MonthHeaderView: View {
    let month: AllTransactionsView.MonthKey
    let summary: AllTransactionsView.Summary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatMonthHeader(month))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if let summary = summary {
                // "In" amount on first line (if > 0)
                if summary.totalIn > 0 {
                    HStack(spacing: 4) {
                        Text(formatAmount(summary.totalIn))
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text("in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // "Out" amount on second line (if > 0)
                if summary.totalOut > 0 {
                    HStack(spacing: 4) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading state for monthly stats
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Calculating totals...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 30)
            }
        }
        .padding(.vertical, 8)
        .textCase(nil)
    }
    
    private func formatMonthHeader(_ month: AllTransactionsView.MonthKey) -> String {
        let dateComponents = DateComponents(year: month.year, month: month.month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return "Unknown"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct DayHeaderView: View {
    let day: AllTransactionsView.DayKey
    let summary: AllTransactionsView.Summary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(formatDayHeader(day))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // Daily summary below the day name - separate lines
            if let summary = summary {
                if summary.totalIn > 0 {
                    HStack(spacing: 4) {
                        Text(formatAmount(summary.totalIn))
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if summary.totalOut > 0 {
                    HStack(spacing: 4) {
                        Text("-\(formatAmount(summary.totalOut))")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading state for stats
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Loading stats...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(height: 20)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .textCase(nil)
    }
    
    private func formatDayHeader(_ day: AllTransactionsView.DayKey) -> String {
        // Use UTC calendar for consistency
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        if calendar.isDateInToday(day.date) {
            return "Today"
        } else if calendar.isDateInYesterday(day.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: day.date)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Transactions List (Extracted)

struct TransactionsListView: View {
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
    
    @EnvironmentObject var accountsService: AccountsService
    
    var body: some View {
        List {
            // Month Sections
            ForEach(sortedMonths, id: \.self) { month in
                Section {
                    // Day Sections
                    ForEach(sortedDays(for: month), id: \.self) { day in
                        Section {
                            // Transactions
                            ForEach(groupedByMonth[month]?[day] ?? [], id: \.id) { transaction in
                                TransactionView(transaction: transaction)
                                    .onAppear {
                                        checkPreload(for: transaction)
                                    }
                            }
                        } header: {
                            DayHeaderView(day: day, summary: dailySummary(for: month, day: day))
                        }
                    }
                } header: {
                    MonthHeaderView(month: month, summary: monthlySummary(for: month))
                }
            }
            
            // Bottom Indicators
            if isLoadingMore {
                bottomLoadingIndicator
            } else if loadingError != nil && hasMore {
                bottomErrorIndicator
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshAction()
        }
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
            Spacer(); ProgressView().tint(.accentColor); Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical)
    }
    
    private var bottomErrorIndicator: some View {
        HStack {
            Spacer()
            VStack {
                Text("Couldn't load more").font(.footnote).foregroundColor(.secondary)
                Button("Retry") { loadMoreAction() }.font(.footnote)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical)
    }
}
