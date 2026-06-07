//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//

import SwiftUI
import LinkKit

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var accountsService: AccountsService
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    @State private var settingsError: String?
    
    var body: some View {
        ZStack {
            ColorPalette.backgroundSecondary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let name = userAccount.currentUser?.name {
                        VStack(spacing: Spacing.sm) {
                            Text("Hello,")
                                .font(Typography.bodySemibold)
                                .foregroundColor(ColorPalette.textSecondary)

                            Text(name)
                                .font(Typography.h2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxl)
                        .background(ColorPalette.backgroundPrimary)
                    }

                    settingsCard
                    accountCard
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .alert("Settings Error", isPresented: Binding(
            get: { settingsError != nil },
            set: { if !$0 { settingsError = nil } }
        )) {
            Button("OK", role: .cancel) { settingsError = nil }
        } message: {
            Text(settingsError ?? "")
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Settings", systemImage: "gearshape")
                .font(Typography.bodySemibold)
                .foregroundColor(ColorPalette.textPrimary)

            Picker("Spending Plan", selection: Binding(
                get: { userAccount.spendingPlanMode },
                set: { newMode in
                    Task {
                        await saveSpendingPlanMode(newMode)
                    }
                }
            )) {
                ForEach(SpendingPlanMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, Spacing.xs)

            Text("Income Basis")
                .font(Typography.bodySemibold)
                .foregroundColor(ColorPalette.textPrimary)

            Picker("Income Basis", selection: Binding(
                get: { userAccount.incomeBasis },
                set: { newBasis in
                    Task {
                        try? await userAccount.updateIncomeBasis(newBasis)
                    }
                }
            )) {
                ForEach(IncomeBasis.allCases, id: \.self) { basis in
                    Text(basis.displayName).tag(basis)
                }
            }
            .pickerStyle(.segmented)
        }
        .profileCardStyle()
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                LinkedAccountsView()
            } label: {
                ProfileRowContent(
                    title: "Linked accounts",
                    systemImage: "building.columns",
                    tint: ColorPalette.textPrimary,
                    isDestructive: false,
                    accessory: "\(accountsService.banksWithAccounts.count)"
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, Spacing.xs)

            ProfileActionRow(
                title: "Sign Out",
                systemImage: "arrow.right.circle",
                tint: ColorPalette.error,
                isDestructive: true,
                action: handleSignOut
            )
        }
        .profileCardStyle()
    }

    private func saveSpendingPlanMode(_ mode: SpendingPlanMode) async {
        do {
            try await userAccount.updateSpendingPlanMode(mode)
        } catch {
            settingsError = error.localizedDescription
        }
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

private struct LinkedAccountsView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var plaidService: PlaidService
    @EnvironmentObject var authManager: AuthManager
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var linkController: LinkController?
    @State private var shouldPresentLink = false
    @State private var repairingItemId: Int?
    @State private var accountError: String?

    var body: some View {
        ZStack {
            ColorPalette.backgroundSecondary
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Linked accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
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

private struct ProfileActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileRowContent(
                title: title,
                systemImage: systemImage,
                tint: tint,
                isDestructive: isDestructive
            )
        }
    }
}

private struct ProfileRowContent: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool
    var accessory: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.body)

            Spacer()

            if let accessory {
                Text(accessory)
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Image(systemName: systemImage)
                .foregroundColor(tint)
        }
        .foregroundColor(isDestructive ? ColorPalette.error : ColorPalette.textPrimary)
        .padding(.vertical, Spacing.md)
    }
}

private extension View {
    func profileCardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorPalette.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}
