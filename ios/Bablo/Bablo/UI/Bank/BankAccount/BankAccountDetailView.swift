//
//  BankAccountDetailView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/16/25.
//

import SwiftUI

struct BankAccountDetailView: View {
    @State var account: BankAccount
    @EnvironmentObject var accountsService: AccountsService
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
        accountsService.banksWithAccounts.first { bank in
            bank.accounts.contains { $0.id == account.id }
        }
    }
    
    // Get last updated timestamp from account
    private var lastUpdatedText: String {
        if let updatedAt = account.updated_at {
            return "Last updated: \(dateFormatter.string(from: updatedAt))"
        } else {
            return "Last updated: Never"
        }
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Account header
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
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
                            .padding(Spacing.xs)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Text(account.name)
                        .font(Typography.h3)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(account._type.capitalized)
                        .font(Typography.bodyMedium)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    if let mask = account.mask {
                        Text("••••\(mask)")
                            .font(Typography.bodyMedium)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                        .font(Typography.h4)
                        .foregroundColor(getAccountColor(account))
                }
                
                Text(lastUpdatedText)
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.top, Spacing.xs)
            }
            .padding(Spacing.md)
            .card()
            .padding(.horizontal, Spacing.lg)
            
            // Action buttons
            HStack(spacing: Spacing.md) {
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
                }
                .primaryButton(isLoading: isRefreshing)
                
                Button(action: {
                    isDeleteAlertShowing = true
                }) {
                    Label("Hide Account", systemImage: "eye.slash")
                }
                .secondaryButton()
                .foregroundColor(ColorPalette.warning)
            }
            .padding(.horizontal, Spacing.lg)
            
            // Transactions section
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Transactions")
                            .font(Typography.h4)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                    
                    if transactionsService.transactions.isEmpty && !transactionsService.isLoading {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "doc.text")
                                .font(Typography.displayLarge)
                                .foregroundColor(ColorPalette.textSecondary)
                            Text("No transactions found")
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.vertical, Spacing.xxxl)
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
                        ColorPalette.backgroundPrimary
                            .opacity(0.7)
                        
                        VStack(spacing: Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading transactions...")
                                .font(Typography.bodyMedium)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .card()
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
        }
        .padding(.vertical, Spacing.xs)
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
                let options = FetchOptions(limit: 50, offset: 0, forceRefresh: true)
                try await transactionsService.fetchTransactionsForAccount(accountId: account.id, options: options)
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
                let options = FetchOptions(limit: 50, offset: 0, forceRefresh: false)
                try await transactionsService.fetchTransactionsForAccount(accountId: account.id, options: options)
            } catch {
                Logger.e("Failed to load transactions: \(error)")
            }
        }
    }
    
    private func hideAccount() async throws {
        try await accountsService.toggleAccountVisibility(accountId: account.id, hidden: true)
    }
    
    private func getAccountColor(_ account: BankAccount) -> Color {
        switch account._type {
        case "depository", "investment":
            return account.current_balance > 0 ? ColorPalette.success : ColorPalette.error
        default:
            return ColorPalette.error
        }
    }
}

struct BankAccountDetailView_Previews: PreviewProvider {
    static var account = BankAccount(
        id: 1,
        item_id: 1,
        name: "Checking Account",
        mask: "1234",
        official_name: "Premier Checking",
        current_balance: 1250.75,
        available_balance: 1200.00,
        _type: "checking",
        subtype: nil,
        hidden: false,
        iso_currency_code: "USD",
        updated_at: Date.now
    )

    static var previews: some View {
        NavigationView {
            BankAccountDetailView(account: account)
                .environmentObject(AccountsService())
        }
    }
}
