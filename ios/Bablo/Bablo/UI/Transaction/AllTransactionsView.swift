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
    @State private var isRefreshing = false
    @State private var showingProfile = false
    @State private var isLoadingMore = false
    @State private var loadingError: Error?
    @State private var scrollViewProxy: ScrollViewProxy?
    
    // Computed index to trigger load more (80% of the way through the list)
    private var loadMoreIndex: Int {
        let threshold = 0.8
        let index = Int(
            Double(transactionsService.transactions.count) * threshold
        )
        return max(0, min(index, transactionsService.transactions.count - 1))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if transactionsService.isLoading && transactionsService.transactions.isEmpty {
                    ProgressView()
                        .tint(.accentColor)
                }
                
                if !transactionsService.transactions.isEmpty {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(zip(transactionsService.transactions.indices, transactionsService.transactions)), id: \.0) { index, transaction in
                                TransactionView(transaction: transaction)
                                    .id("\(transaction.id ?? 0)-\(index)")
                                    .onAppear {
                                        // If this is the transaction at our threshold point
                                        if index == loadMoreIndex {
                                            preloadNextPage()
                                        }
                                    }
                            }
                            
                            // Loading indicator at the bottom
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(.accentColor)
                                    Spacer()
                                }
                                .padding()
                                .id("loadingIndicator")
                                .listRowSeparator(.hidden)
                            }
                            
                            // Error message if loading failed
                            if loadingError != nil && !isLoadingMore && transactionsService.hasNextPage {
                                HStack {
                                    Spacer()
                                    Text("Couldn't load more transactions")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                                .id("errorMessage")
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .onAppear {
                            scrollViewProxy = proxy
                        }
                    }
                }
            }
            
            if transactionsService.transactions.isEmpty && !transactionsService.isLoading {
                VStack {
                    Text("No transactions found")
                        .font(.headline)
                    Text("Pull to refresh")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            NavigationView {
                ProfileView()
            }
        }
        .navigationDestination(for: Bank.self) { bank in
            BankDetailView(bank: bank)
        }
        .navigationDestination(for: BankAccount.self) { account in
            BankAccountDetailView(account: account)
        }
        .refreshable {
            await refreshTransactions()
        }
        .task {
            await refreshTransactions()
        }
    }
    
    private func refreshTransactions() async {
        isRefreshing = true
        loadingError = nil
        
        do {
            // Reset pagination when pulling to refresh
            try await transactionsService.fetchAllTransactions(forceRefresh: true, loadMore: false)
        } catch {
            Logger.e("Failed to refresh transactions: \(error)")
            loadingError = error
        }
        
        isRefreshing = false
    }
    
    private func preloadNextPage() {
        Logger.i("preloadNextPage: hasNextPage: \(transactionsService.hasNextPage), isLoadingMore: \(isLoadingMore), isLoading: \(transactionsService.isLoading)")

        // If we're at the threshold and there are more transactions to load
        if transactionsService.hasNextPage && !isLoadingMore && !transactionsService.isLoading {
            loadMoreTransactions()
        }
    }
    
    private func loadMoreTransactions() {
        // Avoid multiple simultaneous pagination requests
        guard !isLoadingMore && !transactionsService.isLoading && transactionsService.hasNextPage else {
            return
        }
        
        Task {
            isLoadingMore = true
            
            do {
                try await transactionsService.fetchAllTransactions(loadMore: true)
                loadingError = nil
            } catch {
                Logger.e("Failed to load more transactions: \(error)")
                loadingError = error
            }
            
            isLoadingMore = false
        }
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

// Extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
