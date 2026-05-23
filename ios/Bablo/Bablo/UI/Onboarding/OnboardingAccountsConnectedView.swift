import SwiftUI

struct OnboardingAccountsConnectedView: View {
    @EnvironmentObject var accountsService: AccountsService
    let onLinkAnother: () -> Void
    let onContinue: () -> Void

    @Environment(\.babloTheme) private var theme

    // Computed from live account data
    private var cashOnHand: Double {
        accountsService.banksWithAccounts
            .flatMap(\.accounts)
            .reduce(0) { sum, account in
                switch account._type {
                case "depository": return sum + account.current_balance
                case "credit":     return sum - account.current_balance
                default:           return sum
                }
            }
    }

    private var totalAccountCount: Int {
        accountsService.banksWithAccounts.flatMap(\.accounts).count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONNECTED")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(theme.typography.labelTracking)
                            .foregroundStyle(theme.colors.textSecondary.color)

                        Text("You're linked up.")
                            .font(theme.typography.title(size: 34, weight: .bold))
                            .foregroundStyle(theme.colors.textPrimary.color)

                        Text("\(accountsService.banksWithAccounts.count) bank\(accountsService.banksWithAccounts.count == 1 ? "" : "s") · \(totalAccountCount) account\(totalAccountCount == 1 ? "" : "s") · transactions syncing now.")
                            .font(theme.typography.body(size: 15))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 28)

                // Cash on hand card
                VStack(alignment: .leading, spacing: 4) {
                    Text("CASH ON HAND")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(theme.typography.labelTracking)
                        .foregroundStyle(theme.colors.textSecondary.color)

                    HStack(alignment: .lastTextBaseline) {
                        Text(cashOnHand, format: .currency(code: "USD"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.colors.textPrimary.color)

                        Spacer()

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#078A2E") ?? .green)
                                .frame(width: 7, height: 7)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#078A2E") ?? .green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((Color(hex: "#078A2E") ?? .green).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(20)
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 20)

                // Bank groups
                VStack(spacing: 12) {
                    ForEach(accountsService.banksWithAccounts) { bank in
                        BankGroupCard(bank: bank, theme: theme)
                    }
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 12)

                // Sync progress row
                SyncProgressRow(theme: theme)
                    .padding(.horizontal, theme.metrics.screenPadding)
                    .padding(.top, 12)

                // Link another bank
                Button(action: onLinkAnother) {
                    Text("Link another bank")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }

                // CTA
                OnboardingCTAButton(label: "Continue", action: onContinue)
                    .padding(.horizontal, theme.metrics.screenPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Sub-views

private struct BankGroupCard: View {
    let bank: Bank
    let theme: BabloResolvedTheme

    var body: some View {
        VStack(spacing: 0) {
            // Institution header
            HStack(spacing: 12) {
                // Avatar: decoded logo or initial
                Group {
                    if let img = bank.decodedLogo {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        Text(String(bank.bank_name.prefix(1)).uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(bank.primaryColor ?? theme.colors.accent.color)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(bank.bank_name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Text("Connected just now")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#078A2E") ?? .green)
                }

                Spacer()

                Text("\(bank.accounts.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.colors.surfaceMuted.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            // Account rows
            ForEach(bank.accounts) { account in
                HStack {
                    // Account type icon
                    Image(systemName: account._type == "credit" ? "creditcard.fill" : "building.columns.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .frame(width: 32, height: 32)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.colors.textPrimary.color)
                        if let mask = account.mask {
                            Text("•• \(mask)")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.colors.textTertiary.color)
                        }
                    }

                    Spacer()

                    let isCredit = account._type == "credit"
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isCredit
                            ? (Color(hex: "#FF5F6D") ?? .red)
                            : theme.colors.textPrimary.color
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if account != bank.accounts.last {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
    }
}

private struct SyncProgressRow: View {
    let theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(theme.colors.textSecondary.color)
                .scaleEffect(0.85)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulling last 90 days")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.textPrimary.color)
                Text("Transactions categorizing in the background")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer()
        }
        .padding(14)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        )
    }
}

#Preview {
    OnboardingAccountsConnectedView(onLinkAnother: {}, onContinue: {})
        .environmentObject(AccountsService())
        .background(Color(hex: "#F8F5EF"))
}
