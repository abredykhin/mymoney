//
//  BankAccountDetailView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/16/25.
//

import SwiftUI

struct BankAccountDetailView: View {
    @State var account: BankAccount
    @EnvironmentObject var bankAccountsService: BankAccountsService
    @StateObject private var transactionsService = TransactionsService()
    @State private var isDeleteAlertShowing = false
    @State private var isRefreshing = false
    @Environment(\.presentationMode) var presentationMode
    
    // Date formatter for displaying timestamps
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Get parent bank for this account
    private var parentBank: Bank? {
        bankAccountsService.banksWithAccounts.first { bank in
            bank.accounts.contains { $0.id == account.id }
        }
    }
    
    // Get last updated timestamp from either TransactionsService or account
    private var lastUpdatedText: String {
        if let serviceLastUpdated = transactionsService.lastUpdated {
            return "Last updated: \(dateFormatter.string(from: serviceLastUpdated))"
        } else {
            // Fall back to account's update timestamp
            return "Last updated: \(dateFormatter.string(from: account.updated_at))"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Account header
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Bank logo/icon
                    if let logo = parentBank?.decodedLogo {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "building.columns")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(4)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(account.name)
                        .font(.title2.bold())
                        .lineLimit(1)
                }
                
                HStack {
                    Text(account._type.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let mask = account.mask {
                        Text("••••\(mask)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                        .font(.title3.bold())
                        .foregroundColor(getAccountColor(account))
                }
                
                Text(lastUpdatedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation {
                        isRefreshing = true
                    }
                    refreshData()
                }) {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshing)
                
                Button(action: {
                    isDeleteAlertShowing = true
                }) {
                    Label("Hide Account", systemImage: "eye.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
            .padding(.horizontal)
            
            // Transactions section
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Transactions")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Show cached indicator if applicable
                        if transactionsService.isUsingCachedData {
                            Text("Cached")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    if transactionsService.transactions.isEmpty && !transactionsService.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No transactions found")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.vertical, 40)
                    } else {
                        // We keep the list visible even during loading for smoother transitions
                        List {
                            ForEach(transactionsService.transactions, id: \.id) { transaction in
                                TransactionView(transaction: transaction)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .environment(\.defaultMinListRowHeight, 70)
                        .frame(minHeight: 300)
                    }
                }
                
                // Overlay loading indicator instead of replacing content
                if transactionsService.isLoading {
                    ZStack {
                        Color(UIColor.systemBackground)
                            .opacity(0.7)
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading transactions...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.vertical, 8)
        .alert(isPresented: $isDeleteAlertShowing) {
            Alert(
                title: Text("Hide Account"),
                message: Text("This account will be hidden from your balance totals and account lists. You can unhide it later from settings."),
                primaryButton: .default(Text("Hide Account")) {
                    Task {
                        do {
                            try await hideAccount()
                            presentationMode.wrappedValue.dismiss()
                        } catch {
                            Logger.e("Failed to hide account: \(error)")
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            loadTransactions()
        }
        .refreshable {
            withAnimation {
                isRefreshing = true
            }
            refreshData()
        }
    }
    
    private func refreshData() {
        Task {
            do {
                try await transactionsService.fetchAccountTransactions(String(account.id), forceRefresh: true)
                withAnimation {
                    isRefreshing = false
                }
            } catch {
                Logger.e("Failed to refresh transactions: \(error)")
                withAnimation {
                    isRefreshing = false
                }
            }
        }
    }
    
    private func loadTransactions() {
        Task {
            do {
                try await transactionsService.fetchAccountTransactions(String(account.id))
            } catch {
                Logger.e("Failed to load transactions: \(error)")
            }
        }
    }
    
    private func hideAccount() async throws {
        try await bankAccountsService.updateAccountHiddenStatus(accountId: account.id, hidden: true)
    }
    
    private func getAccountColor(_ account: BankAccount) -> Color {
        switch account._type {
        case "depository", "investment":
            return account.current_balance > 0 ? .green : .red
        default:
            return .red
        }
    }
}

struct BankAccountDetailView_Previews: PreviewProvider {
    static var account = BankAccount(id: 1, name: "Checking Account", current_balance: 1250.75, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    
    static var previews: some View {
        NavigationView {
            BankAccountDetailView(account: account)
                .environmentObject(BankAccountsService())
        }
    }
}
