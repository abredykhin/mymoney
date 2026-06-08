//
//  LinkedAccountsView.swift
//  Bablo
//
//  Created for Plaid account health.
//  Redesigned for Mockup 2 & 3.
//

import SwiftUI
import LinkKit

struct LinkedAccountsView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var plaidService: PlaidService
    @EnvironmentObject var authManager: AuthManager
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.babloTheme) private var theme: BabloResolvedTheme

    private let loadsData: Bool

    @State private var linkController: LinkController?
    @State private var shouldPresentLink = false
    @State private var repairingItemId: Int?
    @State private var accountError: String?
    @State private var bankToUnlink: Bank? = nil
    @State private var showingUnlinkConfirmation = false
    @State private var isLinkingNewBank = false

    init(loadsData: Bool = true) {
        self.loadsData = loadsData
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(theme.colors.lineStrong.color)
                    .frame(width: 36, height: 5)
                    .padding(.top, Spacing.sm)
                
                // Custom Sheet Header
                sheetHeader
                
                Divider()
                    .background(theme.colors.line.color)
                    .padding(.top, Spacing.sm)
                
                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        // Global Attention Banner
                        if attentionCount > 0 {
                            globalWarningBanner
                        }
                        
                        // Bank Cards List
                        if accountsService.isLoading && accountsService.banksWithAccounts.isEmpty {
                            ProgressView()
                                .padding(.vertical, Spacing.xxl)
                        } else if accountsService.banksWithAccounts.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(accountsService.banksWithAccounts) { bank in
                                LinkedBankCard(
                                    bank: bank,
                                    isRepairing: repairingItemId == bank.id,
                                    onRepair: {
                                        Task { await repair(bank) }
                                    },
                                    onUnlink: {
                                        bankToUnlink = bank
                                        showingUnlinkConfirmation = true
                                    }
                                )
                            }
                        }
                        
                        if !accountsService.banksWithAccounts.isEmpty {
                            linkNewBankButton
                            securityNotice
                        }
                    }
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.vertical, Spacing.xxl)
                }
            }
        }
        .babloScreenBackground()
        .task {
            guard loadsData else { return }
            try? await accountsService.refreshAccounts(forceRefresh: true)
        }
        .refreshable {
            try? await accountsService.refreshAccounts(forceRefresh: true)
        }
        .sheet(isPresented: $shouldPresentLink, onDismiss: {
            plaidService.currentHandler = nil
            authManager.recordSuccessfulAuthentication()
            shouldPresentLink = false
            repairingItemId = nil
        }) {
            if let linkController {
                linkController
                    .ignoresSafeArea(.all)
            } else {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                    Text("Opening Plaid...")
                        .font(theme.typography.body(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.textSecondary.color)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Account Error", isPresented: Binding(
            get: { accountError != nil },
            set: { if !$0 { accountError = nil } }
        )) {
            Button("OK", role: .cancel) { accountError = nil }
        } message: {
            Text(accountError ?? "")
        }
        .alert("Unlink Bank", isPresented: $showingUnlinkConfirmation, presenting: bankToUnlink) { bank in
            Button("Unlink", role: .destructive) {
                Task {
                    do {
                        try await accountsService.unlinkBank(bankId: bank.id)
                    } catch {
                        accountError = "Failed to unlink bank: \(error.localizedDescription)"
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { bank in
            Text("Are you sure you want to unlink \(bank.bank_name)? This will remove all associated accounts and transactions, which may affect your budget calculations.")
        }
    }

    // MARK: - Calculations
    
    private var bankCount: Int {
        accountsService.banksWithAccounts.count
    }
    
    private var accountCount: Int {
        accountsService.banksWithAccounts.flatMap { $0.accounts }.count
    }
    
    private var attentionCount: Int {
        accountsService.banksWithAccounts.filter { $0.needsAttention }.count
    }
    
    // MARK: - Subviews
    
    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BANKS & CARDS")
                    .font(theme.typography.body(size: 11, weight: .black))
                    .foregroundColor(theme.colors.textTertiary.color)
                    .tracking(1.5)
                
                Text("Linked accounts")
                    .font(theme.typography.title(size: 24, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary.color)
                    
                Text("\(bankCount) bank\(bankCount == 1 ? "" : "s") · \(accountCount) account\(accountCount == 1 ? "" : "s")")
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundColor(theme.colors.textTertiary.color)
            }
            
            Spacer()
            
            // Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary.color)
                    .frame(width: 32, height: 32)
                    .background(theme.colors.surfaceMuted.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                    )
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.lg)
    }

    private var globalWarningBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.colors.danger.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(attentionCount) connection\(attentionCount == 1 ? "" : "s") need a repair")
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundColor(theme.colors.danger.color)
                
                Text("Balances below may be out of date until you reconnect.")
                    .font(theme.typography.body(size: 13, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary.color.opacity(0.85))
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.danger.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.colors.danger.color.opacity(0.18), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "building.columns")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(theme.colors.textTertiary.color)

            Text("No linked accounts")
                .font(theme.typography.body(size: 16, weight: .bold))
                .foregroundColor(theme.colors.textPrimary.color)

            Text("Link a bank from Home to see account health here.")
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundColor(theme.colors.textSecondary.color)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xxl)
    }
    
    private var linkNewBankButton: some View {
        Button(action: {
            Task { await linkNewBank() }
        }) {
            HStack(spacing: 8) {
                if isLinkingNewBank {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
                
                Text("Link a new bank")
                    .font(theme.typography.body(size: 16, weight: .bold))
            }
            .foregroundColor(theme.colors.textPrimary.color)
            .frame(maxWidth: .infinity)
            .frame(height: theme.metrics.buttonHeight)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous)
                    .strokeBorder(
                        theme.colors.lineStrong.color,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 4])
                    )
            )
        }
        .disabled(isLinkingNewBank)
        .padding(.top, Spacing.sm)
    }
    
    private var securityNotice: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("Bank-grade encryption · read-only · powered by Plaid")
                .font(theme.typography.body(size: 12, weight: .semibold))
        }
        .foregroundColor(theme.colors.textTertiary.color)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Plaid Functions

    private func repair(_ bank: Bank) async {
        guard bank.repairable else { return }

        repairingItemId = bank.id

        do {
            let linkToken = try await plaidService.updateItem(itemId: bank.id)
            let config = generateUpdateModeLinkConfig(linkToken: linkToken)
            let handlerResult = Plaid.create(config)

            switch handlerResult {
            case .success(let handler):
                plaidService.currentHandler = handler
                linkController = LinkController(handler: handler)
                shouldPresentLink = true
            case .failure(let error):
                repairingItemId = nil
                accountError = "Failed to open Plaid Link: \(error.localizedDescription)"
            }
        } catch {
            repairingItemId = nil
            accountError = "Failed to start repair: \(error.localizedDescription)"
        }
    }

    private func linkNewBank() async {
        isLinkingNewBank = true
        defer { isLinkingNewBank = false }

        do {
            let linkToken = try await plaidService.createLinkToken()
            let config = generateNewModeLinkConfig(linkToken: linkToken)
            let handlerResult = Plaid.create(config)

            switch handlerResult {
            case .success(let handler):
                plaidService.currentHandler = handler
                linkController = LinkController(handler: handler)
                shouldPresentLink = true
            case .failure(let error):
                accountError = "Failed to initialize Plaid Link: \(error.localizedDescription)"
            }
        } catch {
            accountError = "Failed to start linking: \(error.localizedDescription)"
        }
    }

    private func generateNewModeLinkConfig(linkToken: String) -> LinkTokenConfiguration {
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Logger.i("Link finished successfully: \(success)")
            Task {
                do {
                    try await plaidService.saveNewItem(
                        publicToken: success.publicToken,
                        institutionId: success.metadata.institution.id
                    )
                    try? await accountsService.refreshAccounts(forceRefresh: true)
                } catch {
                    await MainActor.run {
                        accountError = "Failed to save bank connection: \(error.localizedDescription)"
                    }
                }
                await MainActor.run {
                    shouldPresentLink = false
                }
            }
        }
        config.onExit = { exit in
            if let error = exit.error {
                accountError = "Plaid Link exited: \(error.localizedDescription)"
            }
            shouldPresentLink = false
        }
        config.onEvent = { event in
            Logger.d("Plaid Link event: \(event.eventName)")
        }
        return config
    }

    private func generateUpdateModeLinkConfig(linkToken: String) -> LinkTokenConfiguration {
        var config = LinkTokenConfiguration(token: linkToken) { _ in
            Task {
                try? await accountsService.refreshAccounts(forceRefresh: true)
                await MainActor.run {
                    shouldPresentLink = false
                }
            }
        }

        config.onExit = { exit in
            if let error = exit.error {
                accountError = "Plaid Link exited: \(error.localizedDescription)"
            }
            shouldPresentLink = false
        }

        config.onEvent = { event in
            Logger.d("Plaid update-mode event: \(event.eventName)")
        }

        return config
    }
}

private struct LinkedBankCard: View {
    let bank: Bank
    let isRepairing: Bool
    let onRepair: () -> Void
    let onUnlink: () -> Void
    
    @SwiftUI.Environment(\.babloTheme) private var theme: BabloResolvedTheme

    var body: some View {
        VStack(spacing: 0) {
            // Accent bar representing connection health
            if let statusColor = connectionHealthColor {
                Rectangle()
                    .fill(statusColor)
                    .frame(height: 6)
            }
            
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Bank info row
                HStack(alignment: .top, spacing: Spacing.md) {
                    BankLogo(bank: bank)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bank.bank_name)
                            .font(theme.typography.body(size: 16, weight: .bold))
                            .foregroundColor(theme.colors.textPrimary.color)

                        Text(subtitleText)
                            .font(theme.typography.body(size: 12, weight: .semibold))
                            .foregroundColor(theme.colors.textTertiary.color)
                    }

                    Spacer()

                    PlaidHealthBadge(status: bank.healthStatus)
                }
                .padding(.top, connectionHealthColor != nil ? 0 : Spacing.xs)

                // Warning message in card (if needs attention)
                if bank.needsAttention {
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.colors.warning.color)
                            
                        Text(bank.plaid_last_error_message ?? bank.healthStatus.displayMessage)
                            .font(theme.typography.body(size: 12, weight: .semibold))
                            .foregroundColor(theme.colors.textSecondary.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.colors.warning.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.colors.warning.color.opacity(0.18), lineWidth: 1)
                    )
                }

                // Accounts List
                VStack(spacing: 0) {
                    ForEach(bank.accounts) { account in
                        LinkedAccountRow(account: account, isStale: bank.needsAttention)

                        if account != bank.accounts.last {
                            Divider()
                                .background(theme.colors.line.color)
                        }
                    }
                }

                // Action Buttons
                VStack(spacing: Spacing.sm) {
                    if bank.repairable {
                        Button(action: onRepair) {
                            HStack(spacing: 6) {
                                if isRepairing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "link")
                                }

                                Text(isRepairing ? "Opening Plaid..." : "Repair connection")
                                    .font(theme.typography.body(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.babloPrimary)
                        .disabled(isRepairing)
                    }
                    
                    // Unlink bank button
                    Button(action: onUnlink) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Unlink bank")
                        }
                        .font(theme.typography.body(size: 14, weight: .bold))
                        .foregroundColor(theme.colors.danger.color)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(Spacing.lg)
        }
        .babloCard(tone: .surface, padding: 0) // Padding is zero so the top accent bar reaches the card boundary!
    }
    
    private var connectionHealthColor: Color? {
        switch bank.healthStatus {
        case .good:
            return nil
        case .needsReauth, .pendingDisconnect, .pendingExpiration, .newAccountsAvailable:
            return theme.colors.warning.color
        case .permissionRevoked:
            return theme.colors.danger.color
        }
    }
    
    private var subtitleText: String {
        let accountCountText = "\(bank.accounts.count) account\(bank.accounts.count == 1 ? "" : "s")"
        guard bank.healthStatus == .good, let healthDate = bank.plaid_health_updated_at else {
            return accountCountText
        }
        return "\(accountCountText) · synced \(relativeTimeString(for: healthDate))"
    }
    
    private func relativeTimeString(for date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        let minutes = Int(diff / 60)
        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            if hours < 24 {
                return "\(hours)h ago"
            } else {
                let days = hours / 24
                return "\(days)d ago"
            }
        }
    }
}

private struct LinkedAccountRow: View {
    let account: BankAccount
    let isStale: Bool

    @SwiftUI.Environment(\.babloTheme) private var theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: account._type == "credit" ? "creditcard.fill" : "building.columns.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.colors.textSecondary.color)
                .frame(width: 32, height: 32)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.displayName)
                        .font(theme.typography.body(size: 15, weight: .semibold))
                        .foregroundColor(theme.colors.textPrimary.color)
                    
                    if account.hidden {
                        Text("HIDDEN")
                            .font(theme.typography.body(size: 9, weight: .black))
                            .foregroundColor(theme.colors.textTertiary.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.colors.surfaceMuted.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                            )
                    }
                }

                HStack(spacing: 6) {
                    if !account.maskedNumber.isEmpty {
                        Text(account.maskedNumber)
                    }

                    if isStale {
                        Text("· Stale")
                            .foregroundColor(theme.colors.danger.color)
                            .bold()
                    } else if account.accessRevoked {
                        Text("· Access revoked")
                            .foregroundColor(theme.colors.danger.color)
                            .bold()
                    }
                }
                .font(theme.typography.body(size: 12, weight: .medium))
                .foregroundColor(theme.colors.textTertiary.color)
            }

            Spacer()

            Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                .font(theme.typography.body(size: 15, weight: .bold))
                .foregroundColor(isStale ? theme.colors.danger.color : (account._type == "credit" ? theme.colors.danger.color : theme.colors.textPrimary.color))
        }
        .padding(.vertical, Spacing.lg)
    }
}

private struct PlaidHealthBadge: View {
    let status: PlaidItemHealthStatus
    
    @SwiftUI.Environment(\.babloTheme) private var theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: 4) {
            if status == .good {
                Text("●")
                    .font(.system(size: 8))
            }
            Text(status.displayTitle)
        }
        .font(theme.typography.body(size: 12, weight: .bold))
        .foregroundColor(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(Capsule())
    }

    private var foreground: Color {
        switch status {
        case .good:
            return theme.colors.success.color
        case .needsReauth, .pendingDisconnect, .pendingExpiration, .newAccountsAvailable:
            return theme.colors.warning.color
        case .permissionRevoked:
            return theme.colors.danger.color
        }
    }

    private var background: Color {
        foreground.opacity(0.12)
    }
}

private struct BankLogo: View {
    let bank: Bank
    
    @SwiftUI.Environment(\.babloTheme) private var theme: BabloResolvedTheme

    var body: some View {
        Group {
            if let logo = bank.logo {
                AsyncBankLogoView(
                    logoString: logo,
                    placeholderText: String(bank.bank_name.prefix(1)).uppercased(),
                    backgroundColor: bank.primaryColor ?? theme.colors.accent.color,
                    fontSize: 16
                )
            } else {
                Text(String(bank.bank_name.prefix(1)).uppercased())
                    .font(theme.typography.body(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bank.primaryColor ?? theme.colors.accent.color)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#if DEBUG
enum LinkedAccountsPreviewState {
    case normal
    case attention
}

@MainActor
enum ProfilePreviewFixtures {
    static func userAccount() -> UserAccount {
        let account = UserAccount()
        account.currentUser = User(
            id: "preview-user",
            name: "Mia",
            token: "",
            email: "mia@example.com"
        )
        account.isSignedIn = true
        account.spendingPlanMode = .monthlyPlan
        account.incomeBasis = .projected
        return account
    }

    static func accountsService(_ state: LinkedAccountsPreviewState) -> AccountsService {
        let service = AccountsService()
        service.banksWithAccounts = banks(for: state)
        service.lastUpdated = Date()
        return service
    }

    static func plaidService() -> PlaidService {
        PlaidService()
    }

    static func authManager() -> AuthManager {
        AuthManager()
    }

    private static func banks(for state: LinkedAccountsPreviewState) -> [Bank] {
        switch state {
        case .normal:
            return [
                bank(
                    id: 1,
                    name: "Chase",
                    color: "#005EB8",
                    status: .good,
                    accounts: [
                        account(
                            id: 1,
                            itemId: 1,
                            name: "Everyday Checking",
                            officialName: "Chase Total Checking",
                            mask: "3382",
                            balance: 1_920.44,
                            type: "depository",
                            subtype: "checking"
                        ),
                        account(
                            id: 2,
                            itemId: 1,
                            name: "Freedom Card",
                            officialName: "Chase Freedom",
                            mask: "1188",
                            balance: 420.18,
                            type: "credit",
                            subtype: "credit card"
                        ),
                        account(
                            id: 3,
                            itemId: 1,
                            name: "Old Savings",
                            officialName: "Chase Savings",
                            mask: "4100",
                            balance: 250.0,
                            type: "depository",
                            subtype: "savings",
                            hidden: true
                        )
                    ]
                ),
                bank(
                    id: 2,
                    name: "SoFi",
                    color: "#00A8A8",
                    status: .good,
                    accounts: [
                        account(
                            id: 4,
                            itemId: 2,
                            name: "Savings",
                            officialName: "SoFi Savings",
                            mask: "9022",
                            balance: 8_450.72,
                            type: "depository",
                            subtype: "savings"
                        )
                    ]
                )
            ]
        case .attention:
            return [
                bank(
                    id: 10,
                    name: "Wells Fargo",
                    color: "#D71E28",
                    status: .needsReauth,
                    errorCode: "ITEM_LOGIN_REQUIRED",
                    errorMessage: "Wells Fargo needs your credentials refreshed before syncing can continue.",
                    accounts: [
                        account(
                            id: 10,
                            itemId: 10,
                            name: "Checking",
                            officialName: "Everyday Checking",
                            mask: "7710",
                            balance: 640.12,
                            type: "depository",
                            subtype: "checking"
                        )
                    ]
                ),
                bank(
                    id: 11,
                    name: "Capital One",
                    color: "#004977",
                    status: .pendingExpiration,
                    accounts: [
                        account(
                            id: 11,
                            itemId: 11,
                            name: "Venture",
                            officialName: "Capital One Venture",
                            mask: "0042",
                            balance: 1_204.33,
                            type: "credit",
                            subtype: "credit card"
                        )
                    ]
                ),
                bank(
                    id: 12,
                    name: "American Express",
                    color: "#006FCF",
                    status: .permissionRevoked,
                    accounts: [
                        account(
                            id: 12,
                            itemId: 12,
                            name: "Blue Cash",
                            officialName: "Blue Cash Preferred",
                            mask: "1009",
                            balance: 312.90,
                            type: "credit",
                            subtype: "credit card",
                            revoked: true
                        )
                    ]
                ),
                bank(
                    id: 13,
                    name: "Bank of America",
                    color: "#E31837",
                    status: .newAccountsAvailable,
                    accounts: [
                        account(
                            id: 13,
                            itemId: 13,
                            name: "Advantage Savings",
                            officialName: "Advantage Savings",
                            mask: "8812",
                            balance: 2_190.00,
                            type: "depository",
                            subtype: "savings"
                        )
                    ]
                )
            ]
        }
    }

    private static func bank(
        id: Int,
        name: String,
        color: String,
        status: PlaidItemHealthStatus,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        accounts: [BankAccount]
    ) -> Bank {
        Bank(
            id: id,
            bank_name: name,
            logo: nil,
            primary_color: color,
            url: nil,
            plaid_item_id: "preview_item_\(id)",
            item_status: status.rawValue,
            plaid_health_updated_at: Date(),
            plaid_last_error_code: errorCode,
            plaid_last_error_message: errorMessage,
            plaid_access_expires_at: status == .pendingExpiration ? Date().addingTimeInterval(86400 * 7) : nil,
            accounts: accounts
        )
    }

    private static func account(
        id: Int,
        itemId: Int,
        name: String,
        officialName: String,
        mask: String,
        balance: Double,
        type: String,
        subtype: String,
        hidden: Bool = false,
        revoked: Bool = false
    ) -> BankAccount {
        BankAccount(
            id: id,
            item_id: itemId,
            name: name,
            mask: mask,
            official_name: officialName,
            current_balance: balance,
            available_balance: type == "depository" ? balance : nil,
            _type: type,
            subtype: subtype,
            hidden: hidden,
            iso_currency_code: "USD",
            updated_at: Date(),
            plaid_access_revoked_at: revoked ? Date() : nil
        )
    }
}

#Preview("Linked Accounts · Normal") {
    LinkedAccountsView(loadsData: false)
        .environmentObject(ProfilePreviewFixtures.accountsService(.normal))
        .environmentObject(ProfilePreviewFixtures.plaidService())
        .environmentObject(ProfilePreviewFixtures.authManager())
        .babloTheme(.normal)
}

#Preview("Linked Accounts · Needs Repair") {
    LinkedAccountsView(loadsData: false)
        .environmentObject(ProfilePreviewFixtures.accountsService(.attention))
        .environmentObject(ProfilePreviewFixtures.plaidService())
        .environmentObject(ProfilePreviewFixtures.authManager())
        .babloTheme(.normal)
}
#endif

// MARK: - Async Bank Logo View
struct AsyncBankLogoView: View {
    let logoString: String
    let placeholderText: String
    let backgroundColor: Color
    var fontSize: CGFloat = 16
    
    @State private var decodedImage: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(placeholderText)
                    .font(.system(size: fontSize, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
            }
        }
        .task(id: logoString) {
            await loadLogo()
        }
    }
    
    private func loadLogo() async {
        guard !logoString.isEmpty else { return }
        
        // Check if it's a web URL
        if logoString.hasPrefix("http://") || logoString.hasPrefix("https://") {
            guard let url = URL(string: logoString) else { return }
            isLoading = true
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.decodedImage = image
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { self.isLoading = false }
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
            return
        }
        
        // Otherwise, assume it is base64 data URL or raw base64
        isLoading = true
        // Decode on background thread
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            var base64String = logoString
            if logoString.hasPrefix("data:image") {
                let components = logoString.components(separatedBy: ",")
                guard components.count == 2 else { return nil }
                base64String = components[1]
            }
            
            guard let data = Data(base64Encoded: base64String) else {
                return nil
            }
            return UIImage(data: data)
        }.value
        
        await MainActor.run {
            self.decodedImage = image
            self.isLoading = false
        }
    }
}
