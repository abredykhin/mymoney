//
//  LinkedAccountsView.swift
//  Bablo
//
//  Created for Plaid account health.
//

import SwiftUI
import LinkKit

struct LinkedAccountsView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var plaidService: PlaidService
    @EnvironmentObject var authManager: AuthManager
    @SwiftUI.Environment(\.dismiss) private var dismiss

    private let loadsData: Bool

    @State private var linkController: LinkController?
    @State private var shouldPresentLink = false
    @State private var repairingItemId: Int?
    @State private var accountError: String?

    init(loadsData: Bool = true) {
        self.loadsData = loadsData
    }

    var body: some View {
        ZStack {
            ColorPalette.backgroundSecondary
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Linked accounts")
        .navigationBarTitleDisplayMode(.inline)
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
                        .font(Typography.body)
                        .foregroundColor(ColorPalette.textSecondary)
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
    }

    @ViewBuilder
    private var content: some View {
        if accountsService.isLoading && accountsService.banksWithAccounts.isEmpty {
            ProgressView()
        } else if accountsService.banksWithAccounts.isEmpty {
            VStack(spacing: Spacing.md) {
                Image(systemName: "building.columns")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)

                Text("No linked accounts")
                    .font(Typography.bodySemibold)
                    .foregroundColor(ColorPalette.textPrimary)

                Text("Link a bank from Home to see account health here.")
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
        } else {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ForEach(accountsService.banksWithAccounts) { bank in
                        LinkedBankCard(
                            bank: bank,
                            isRepairing: repairingItemId == bank.id,
                            onRepair: {
                                Task { await repair(bank) }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                BankLogo(bank: bank)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bank.bank_name)
                        .font(Typography.bodySemibold)
                        .foregroundColor(ColorPalette.textPrimary)

                    Text("\(bank.accounts.count) account\(bank.accounts.count == 1 ? "" : "s")")
                        .font(Typography.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Spacer()

                PlaidHealthBadge(status: bank.healthStatus)
            }

            if bank.needsAttention {
                Text(bank.plaid_last_error_message ?? bank.healthStatus.displayMessage)
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(bank.accounts) { account in
                    LinkedAccountRow(account: account)

                    if account != bank.accounts.last {
                        Divider()
                    }
                }
            }

            if bank.repairable {
                Button(action: onRepair) {
                    HStack {
                        if isRepairing {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isRepairing ? "Opening Plaid..." : "Repair connection")
                            .font(Typography.bodySemibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.babloPrimary)
                .disabled(isRepairing)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}

private struct LinkedAccountRow: View {
    let account: BankAccount

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: account._type == "credit" ? "creditcard.fill" : "building.columns.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 30, height: 30)
                .background(ColorPalette.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textPrimary)

                HStack(spacing: 6) {
                    if !account.maskedNumber.isEmpty {
                        Text(account.maskedNumber)
                    }

                    if account.hidden {
                        Text("Hidden")
                    }

                    if account.accessRevoked {
                        Text("Access revoked")
                    }
                }
                .font(Typography.caption)
                .foregroundColor(account.accessRevoked ? ColorPalette.error : ColorPalette.textSecondary)
            }

            Spacer()

            Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                .font(Typography.bodySemibold)
                .foregroundColor(account._type == "credit" ? ColorPalette.error : ColorPalette.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }
}

private struct PlaidHealthBadge: View {
    let status: PlaidItemHealthStatus

    var body: some View {
        Text(status.displayTitle)
            .font(Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch status {
        case .good:
            return ColorPalette.success
        case .needsReauth, .pendingDisconnect, .pendingExpiration, .newAccountsAvailable:
            return ColorPalette.warning
        case .permissionRevoked:
            return ColorPalette.error
        }
    }

    private var background: Color {
        foreground.opacity(0.12)
    }
}

private struct BankLogo: View {
    let bank: Bank

    var body: some View {
        Group {
            if let image = bank.decodedLogo {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(String(bank.bank_name.prefix(1)).uppercased())
                    .font(Typography.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bank.primaryColor ?? ColorPalette.primary)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
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
    NavigationStack {
        LinkedAccountsView(loadsData: false)
            .environmentObject(ProfilePreviewFixtures.accountsService(.normal))
            .environmentObject(ProfilePreviewFixtures.plaidService())
            .environmentObject(ProfilePreviewFixtures.authManager())
    }
    .babloTheme(.normal)
}

#Preview("Linked Accounts · Needs Repair") {
    NavigationStack {
        LinkedAccountsView(loadsData: false)
            .environmentObject(ProfilePreviewFixtures.accountsService(.attention))
            .environmentObject(ProfilePreviewFixtures.plaidService())
            .environmentObject(ProfilePreviewFixtures.authManager())
    }
    .babloTheme(.normal)
}
#endif
