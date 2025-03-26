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
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if transactionsService.isLoading && transactionsService.transactions.isEmpty {
                    ProgressView()
                        .tint(.accentColor)
                }
                
                List {
                    ForEach(transactionsService.transactions, id: \.id) { transaction in
                        TransactionView(transaction: transaction)
                    }
                    
                    // Pagination loading trigger and indicator
                    if transactionsService.hasNextPage {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.accentColor)
                                .onAppear {
                                    loadMoreTransactions()
                                }
                            Spacer()
                        }
                        .padding()
                    }
                }
                .listStyle(.plain)
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
        do {
            try await transactionsService.fetchAllTransactions(forceRefresh: true)
        } catch {
            Logger.e("Failed to refresh transactions: \(error)")
        }
        isRefreshing = false
    }
    
    private func loadMoreTransactions() {
        // Avoid multiple simultaneous pagination requests
        guard !isLoadingMore && !transactionsService.isLoading && transactionsService.hasNextPage else {
            return
        }
        
        Task {
            isLoadingMore = true
            do {
                try await transactionsService.loadMoreAllTransactions()
            } catch {
                Logger.e("Failed to load more transactions: \(error)")
            }
            isLoadingMore = false
        }
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

#Preview {
    AllTransactionsView()
        .environmentObject(TransactionsService())
        .environmentObject(UserAccount())
}