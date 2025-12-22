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

    @State private var showingProfile = false
    @State private var isLoadingMore = false // Keep for bottom indicator logic
    @State private var loadingError: Error?
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Use local timezone so dates match what's displayed
        formatter.timeZone = TimeZone.current
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
        let calendar = Calendar.current
        var result: [MonthKey: [DayKey: [Transaction]]] = [:]

        for transaction in transactionsService.transactions {
            let dateFromString = AllTransactionsView.dateFormatter.date(from: transaction.date)
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

    // Calculate summary for a month (excluding transfers)
    private func monthlySummary(for month: MonthKey) -> Summary {
        guard let daysInMonth = groupedByMonth[month] else {
            return Summary(totalIn: 0, totalOut: 0)
        }

        var totalIn: Double = 0
        var totalOut: Double = 0

        for (_, transactions) in daysInMonth {
            for transaction in transactions {
                // Skip transfers - they don't count as income or expenses
                if transaction.isTransfer {
                    continue
                }

                if transaction.amount > 0 {
                    totalIn += transaction.amount
                } else {
                    totalOut += abs(transaction.amount)
                }
            }
        }

        return Summary(totalIn: totalIn, totalOut: totalOut)
    }

    // Calculate summary for a specific day (excluding transfers)
    private func dailySummary(for month: MonthKey, day: DayKey) -> Summary {
        guard let transactions = groupedByMonth[month]?[day] else {
            return Summary(totalIn: 0, totalOut: 0)
        }

        var totalIn: Double = 0
        var totalOut: Double = 0

        for transaction in transactions {
            // Skip transfers - they don't count as income or expenses
            if transaction.isTransfer {
                continue
            }

            if transaction.amount > 0 {
                totalIn += transaction.amount
            } else {
                totalOut += abs(transaction.amount)
            }
        }

        return Summary(totalIn: totalIn, totalOut: totalOut)
    }

    // Computed index to trigger load more (based on the original flat list)
    private var loadMoreThresholdIndex: Int {
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
                        .frame(maxHeight: .infinity) // Center it
                } else if !transactionsService.transactions.isEmpty {
                    List {
                        // Iterate over sorted months
                        ForEach(sortedMonths, id: \.self) { month in
                            Section {
                                // Iterate over sorted days in this month
                                ForEach(sortedDays(for: month), id: \.self) { day in
                                    // Day sub-section
                                    Section {
                                        // Transactions for this day
                                        ForEach(groupedByMonth[month]?[day] ?? [], id: \.id) { transaction in
                                            TransactionView(transaction: transaction)
                                                .onAppear {
                                                    // Check if this transaction is near the end of the *original* list
                                                    if let originalIndex = transactionsService.transactions.firstIndex(where: { $0.id == transaction.id }) {
                                                        if originalIndex >= loadMoreThresholdIndex {
                                                            preloadNextPage()
                                                        }
                                                    }
                                                }
                                        }
                                    } header: {
                                        // Day header with summary
                                        let summary = dailySummary(for: month, day: day)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(formatDayHeader(day))
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)

                                            // Daily summary below the day name - separate lines
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
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .textCase(nil)
                                    }
                                }
                            } header: {
                                // Month header with summary
                                let summary = monthlySummary(for: month)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatMonthHeader(month))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

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
                                }
                                .padding(.vertical, 8)
                                .textCase(nil)
                            }
                        }

                        // --- Loading Indicator and Error Message at the bottom ---
                        if isLoadingMore {
                            bottomLoadingIndicator
                        } else if loadingError != nil && (transactionsService.paginationInfo?.hasMore ?? false) {
                            // Show error only if there was an error AND we expect more pages
                            // Avoid showing error if we simply reached the end
                            bottomErrorIndicator
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshTransactions()
                    }
                } else if !transactionsService.isLoading { // Empty state (after initial load attempt)
                    VStack {
                        Text("No transactions found")
                            .font(.headline)
                        Text("Pull to refresh")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                    
                    ScrollView { EmptyView() }
                        .refreshable {
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
            }
        }
    }
    
    private var bottomLoadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.accentColor)
            Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical)
        .id("loadingIndicator")
    }
    
    private var bottomErrorIndicator: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                Text("Couldn't load more transactions")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                Button("Retry") {
                    loadMoreTransactions()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical)
        .id("errorMessage")
    }
    
    
    // MARK: - Formatting Helpers

    private func formatMonthHeader(_ month: MonthKey) -> String {
        let dateComponents = DateComponents(year: month.year, month: month.month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return "Unknown"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatDayHeader(_ day: DayKey) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date) {
            return "Today"
        } else if calendar.isDateInYesterday(day.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
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
        
    private func refreshTransactions() async {
        loadingError = nil // Clear previous errors on refresh
        isLoadingMore = false // Ensure bottom indicator isn't stuck
        do {
            try await transactionsService.fetchRecentTransactions(forceRefresh: true, loadMore: false)
        } catch {
            Logger.e("Failed to refresh transactions: \(error)")
            loadingError = error
        }
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
