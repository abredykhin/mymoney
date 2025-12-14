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
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Group transactions by the start of the day
    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: transactionsService.transactions) { transaction in
            let dateFromString = AllTransactionsView.dateFormatter.date(from: transaction.date) // Use the static formatter
            let validDate = dateFromString ?? Date.distantPast
            return Calendar.current.startOfDay(for: validDate)
        }
    }
    
    // Sort the date keys (newest first)
    private var sortedDates: [Date] {
        groupedTransactions.keys.sorted(by: >) // Sort descending
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
                        // Iterate over sorted dates (days)
                        ForEach(sortedDates, id: \.self) { date in
                            // Section for each date
                            Section {
                                // Iterate over transactions for THAT date
                                // Ensure transactions within the day are sorted if needed (e.g., by time descending)
                                ForEach(groupedTransactions[date] ?? [], id: \.id) { transaction in
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
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 4)
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
    
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .long, time: .omitted)
        }
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
//#Preview("Normal State - With Transactions") {
//    let service = TransactionsService()
//    
//    // Generate 50 mock transactions
//    let mockTransactions = (0..<5).map { i in
//        Transaction(
//            id: i,
//            amount: Double.random(in: 5...200),
//            iso_currency_code: "USD",
//            authorized_date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            category: ["Food", "Shopping", "Entertainment", "Transport", "Bills"][i % 5],
//            pending: i % 10 == 0,
//            merchant_name: ["Starbucks", "Amazon", "Netflix", "Uber", "Walmart"][i % 5],
//            name: "Transaction #\(i)"
//        )
//    }
//    
//    // Set transactions and pagination
//    service.transactions = mockTransactions
//    service.paginationInfo = PaginationInfo(totalCount: 100, limit: 50, hasMore: true, nextCursor: "next_page_token")
//    service.hasNextPage = true
//    service.isLoading = false
//    
//    AllTransactionsView()
//        .environmentObject(service)
//        .environmentObject(UserAccount())
//        .environmentObject(NavigationState())
//}

//#Preview("Empty State") {
//    let service = TransactionsService()
//    
//    // Empty transactions list
//    service.transactions = []
//    service.isLoading = false
//    
//    AllTransactionsView()
//        .environmentObject(service)
//        .environmentObject(UserAccount())
//        .environmentObject(NavigationState())
//}

//#Preview("Loading Error State") {
//    let service = TransactionsService()
//    
//    // Some transactions but with a loading error
//    let mockTransactions = (0..<5).map { i in
//        Transaction(
//            id: i,
//            amount: Double.random(in: 5...200),
//            iso_currency_code: "USD",
//            authorized_date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            category: ["Food", "Shopping", "Entertainment", "Transport", "Bills"][i % 5],
//            pending: i % 10 == 0,
//            merchant_name: ["Starbucks", "Amazon", "Netflix", "Uber", "Walmart"][i % 5],
//            name: "Transaction #\(i)"
//        )
//    }
//    
//    service.transactions = mockTransactions
//    service.paginationInfo = PaginationInfo(totalCount: 100, limit: 50, hasMore: true, nextCursor: "next_page_token")
//    service.hasNextPage = true
//    service.isLoading = false
//    
//    // Simulate a view with loading error
//    AllTransactionsView(loadingError: NSError(domain: "TransactionService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to load more transactions"]))
//        .environmentObject(service)
//        .environmentObject(UserAccount())
//        .environmentObject(NavigationState())
//}
//
//#Preview("Initial Loading") {
//    let service = TransactionsService()
//    
//    // Set loading state with empty transactions
//    service.transactions = []
//    service.isLoading = true
//    
//    AllTransactionsView()
//        .environmentObject(service)
//        .environmentObject(UserAccount())
//        .environmentObject(NavigationState())
//}
//
//#Preview("Loading More") {
//    let service = TransactionsService()
//    
//    // Generate some mock transactions
//    let mockTransactions = (0..<5).map { i in
//        Transaction(
//            id: i,
//            amount: Double.random(in: 5...200),
//            iso_currency_code: "USD",
//            authorized_date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            date: "2024-03-\(String(format: "%02d", min(25, i % 25 + 1)))",
//            category: ["Food", "Shopping", "Entertainment", "Transport", "Bills"][i % 5],
//            pending: i % 10 == 0,
//            merchant_name: ["Starbucks", "Amazon", "Netflix", "Uber", "Walmart"][i % 5],
//            name: "Transaction #\(i)"
//        )
//    }
//    
//    // Set transactions and pagination with loading indicator
//    service.transactions = mockTransactions
//    service.paginationInfo = PaginationInfo(totalCount: 100, limit: 50, hasMore: true, nextCursor: "next_page_token")
//    service.hasNextPage = true
//    service.isLoading = false
//    
//    // Simulate a view that's loading more
//    AllTransactionsView(isLoadingMore: true)
//        .environmentObject(service)
//        .environmentObject(UserAccount())
//        .environmentObject(NavigationState())
//}
