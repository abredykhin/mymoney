//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//  Redesigned for Mockup 1.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var accountsService: AccountsService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.babloTheme) private var theme: BabloResolvedTheme
    @AppStorage("babloThemeVariant") private var babloThemeVariant = BabloTheme.normal.rawValue
    
    @State private var isManagingAccounts = false
    @State private var activePlaceholder: PlaceholderSheetData? = nil
    @State private var settingsError: String?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    profileHeaderCard
                    
                    linkedAccountsCard
                    
                    optionsCardBlock
                    
                    signOutCard
                    
                    footerVersion
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
        .babloScreenBackground()
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .alert("Settings Error", isPresented: Binding(
            get: { settingsError != nil },
            set: { if !$0 { settingsError = nil } }
        )) {
            Button("OK", role: .cancel) { settingsError = nil }
        } message: {
            Text(settingsError ?? "")
        }
        .sheet(isPresented: $isManagingAccounts, onDismiss: {
            Task {
                try? await accountsService.refreshAccounts(forceRefresh: true)
            }
        }) {
            LinkedAccountsView()
        }
        .sheet(item: $activePlaceholder) { data in
            FeaturePlaceholderSheet(
                title: data.title,
                subtitle: data.subtitle,
                description: data.description,
                systemImage: data.systemImage,
                iconColor: data.iconColor
            )
        }
    }
    
    // MARK: - User Info Calculations
    private var userName: String {
        userAccount.currentUser?.name ?? "User"
    }
    
    private var userEmail: String {
        userAccount.currentUser?.email ?? "noemail@bablo.app"
    }
    
    private var initials: String {
        let components = userName.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(userName.prefix(1)).uppercased()
    }
    
    // MARK: - Subviews
    
    private var profileHeaderCard: some View {
        HStack(spacing: Spacing.md) {
            // Circle Avatar with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.avatarPink.color, theme.colors.avatarPink.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Text(initials)
                    .font(theme.typography.title(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(theme.typography.title(size: 18, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary.color)
                
                Text(userEmail)
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary.color)
            }
            
            Spacer()
            
            // "Free" Badge
            HStack(spacing: 4) {
                Image(systemName: "star")
                    .font(.system(size: 11, weight: .bold))
                Text("Free")
                    .font(theme.typography.body(size: 12, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundColor(theme.colors.textSecondary.color)
            .background(theme.colors.surfaceMuted.color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
            )
        }
        .babloCard(tone: .surface, padding: Spacing.md)
    }
    
    private var linkedAccountsCard: some View {
        let bankCount = accountsService.banksWithAccounts.count
        let accountCount = accountsService.banksWithAccounts.flatMap { $0.accounts }.count
        let attentionCount = accountsService.banksWithAccounts.filter { $0.needsAttention }.count
        
        return Button(action: { isManagingAccounts = true }) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("LINKED ACCOUNTS")
                        .font(theme.typography.body(size: 11, weight: .black))
                        .foregroundColor(theme.colors.textTertiary.color)
                        .tracking(1.2)
                    
                    Spacer()
                    
                    if attentionCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(attentionCount) need repair")
                                .font(theme.typography.body(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor(theme.colors.danger.color)
                        .background(theme.colors.danger.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountsService.totalBalance, format: .currency(code: "USD"))
                            .font(theme.typography.title(size: 32, weight: .black))
                            .foregroundColor(theme.colors.textPrimary.color)
                            .minimumScaleFactor(0.8)
                        
                        Text("net tracked · \(bankCount) bank\(bankCount == 1 ? "" : "s") · \(accountCount) account\(accountCount == 1 ? "" : "s")")
                            .font(theme.typography.body(size: 13, weight: .medium))
                            .foregroundColor(theme.colors.textTertiary.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.colors.textSecondary.color)
                        .frame(width: 32, height: 32)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                        )
                }
                
                Divider()
                    .background(theme.colors.line.color)
                    .padding(.vertical, 2)
                
                HStack {
                    MiniBankLogos(banks: accountsService.banksWithAccounts)
                    
                    Spacer()
                    
                    Text("Tap to manage")
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundColor(theme.colors.textTertiary.color)
                }
            }
            .babloCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var optionsCardBlock: some View {
        VStack(spacing: 0) {
            OptionRow(
                title: "Upgrade to Bablo+",
                subtitle: "Unlimited goals, smarter coach",
                iconName: "star.fill",
                iconColor: theme.colors.success.color,
                iconBgColor: theme.colors.success.color.opacity(0.12)
            ) {
                activePlaceholder = PlaceholderSheetData(
                    title: "Upgrade to Bablo+",
                    subtitle: "Unlimited goals, smarter coach",
                    description: "Bablo+ gives you advanced tools to optimize your cashflow: track unlimited savings goals, receive direct notifications from our AI coach, and customize category weights for advanced cashflow projections.",
                    systemImage: "star.fill",
                    iconColor: theme.colors.success.color
                )
            }
            
            Divider()
                .background(theme.colors.line.color)
                .padding(.vertical, 2)
            
            OptionRow(
                title: "Security & privacy",
                subtitle: "Face ID, data controls",
                iconName: "shield.fill",
                iconColor: theme.colors.textSecondary.color,
                iconBgColor: theme.colors.surfaceMuted.color
            ) {
                activePlaceholder = PlaceholderSheetData(
                    title: "Security & privacy",
                    subtitle: "Face ID, data controls",
                    description: "Secure your financial data with biometric locking and choose exactly which items and transaction scopes are shared with our optimization models.",
                    systemImage: "shield.fill",
                    iconColor: theme.colors.textSecondary.color
                )
            }
            
            Divider()
                .background(theme.colors.line.color)
                .padding(.vertical, 2)
            
            OptionRow(
                title: "Notifications",
                subtitle: "Bills, streaks, coach nudges",
                iconName: "bell.fill",
                iconColor: theme.colors.textSecondary.color,
                iconBgColor: theme.colors.surfaceMuted.color
            ) {
                activePlaceholder = PlaceholderSheetData(
                    title: "Notifications",
                    subtitle: "Bills, streaks, coach nudges",
                    description: "Never miss a sync update, streak milestone, or AI coach insight. Choose exactly what push notifications you want to receive.",
                    systemImage: "bell.fill",
                    iconColor: theme.colors.textSecondary.color
                )
            }
            
            Divider()
                .background(theme.colors.line.color)
                .padding(.vertical, 2)
            
            themeToggleRow
            
            Divider()
                .background(theme.colors.line.color)
                .padding(.vertical, 2)
            
            OptionRow(
                title: "Help & support",
                subtitle: nil,
                iconName: "questionmark.circle.fill",
                iconColor: theme.colors.textSecondary.color,
                iconBgColor: theme.colors.surfaceMuted.color
            ) {
                activePlaceholder = PlaceholderSheetData(
                    title: "Help & support",
                    subtitle: "Bablo documentation and support",
                    description: "Need help? Read our documentation, contact customer support, or submit feedback to help us build a better MyMoney experience.",
                    systemImage: "questionmark.circle.fill",
                    iconColor: theme.colors.textSecondary.color
                )
            }
        }
        .babloCard(padding: Spacing.md)
    }
    
    private var themeToggleRow: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.info.color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.colors.info.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pop theme")
                    .font(theme.typography.body(size: 16, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary.color)
                Text("Halftones, bold borders, retro look")
                    .font(theme.typography.body(size: 12, weight: .medium))
                    .foregroundColor(theme.colors.textTertiary.color)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { babloThemeVariant == BabloTheme.pop.rawValue },
                set: { babloThemeVariant = $0 ? BabloTheme.pop.rawValue : BabloTheme.normal.rawValue }
            ))
            .labelsHidden()
            .tint(theme.colors.accent.color)
            .accessibilityIdentifier("me.popThemeToggle")
        }
        .padding(.vertical, Spacing.sm)
    }
    
    private var signOutCard: some View {
        Button(action: handleSignOut) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.colors.danger.color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.colors.danger.color)
                }
                
                Text("Sign out")
                    .font(theme.typography.body(size: 16, weight: .bold))
                    .foregroundColor(theme.colors.danger.color)
                
                Spacer()
            }
            .padding(.vertical, 4)
            .babloCard(padding: Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var footerVersion: some View {
        Text("Bablo v2.4.0 · Made for your money")
            .font(theme.typography.body(size: 12, weight: .medium))
            .foregroundColor(theme.colors.textTertiary.color)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

// MARK: - Helper Views

private struct OptionRow: View {
    let title: String
    let subtitle: String?
    let iconName: String
    let iconColor: Color
    let iconBgColor: Color
    let action: () -> Void
    
    @Environment(\.babloTheme) private var theme: BabloResolvedTheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconBgColor)
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.typography.body(size: 16, weight: .bold))
                        .foregroundColor(theme.colors.textPrimary.color)
                    if let subtitle {
                        Text(subtitle)
                            .font(theme.typography.body(size: 12, weight: .medium))
                            .foregroundColor(theme.colors.textTertiary.color)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.colors.textTertiary.color)
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MiniBankLogos: View {
    let banks: [Bank]
    @Environment(\.babloTheme) private var theme: BabloResolvedTheme
    
    var body: some View {
        HStack(spacing: -6) {
            ForEach(banks.prefix(5)) { bank in
                Group {
                    if let logo = bank.logo {
                        AsyncBankLogoView(
                            logoString: logo,
                            placeholderText: String(bank.bank_name.prefix(1)).uppercased(),
                            backgroundColor: bank.primaryColor ?? theme.colors.accent.color,
                            fontSize: 10
                        )
                    } else {
                        Text(String(bank.bank_name.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(bank.primaryColor ?? theme.colors.accent.color)
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.colors.surface.color, lineWidth: 1.5)
                )
            }
        }
    }
}

struct PlaceholderSheetData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let iconColor: Color
}

#if DEBUG
#Preview("Profile · Normal") {
    NavigationStack {
        ProfileView()
            .environmentObject(ProfilePreviewFixtures.userAccount())
            .environmentObject(ProfilePreviewFixtures.accountsService(.normal))
            .environmentObject(ProfilePreviewFixtures.plaidService())
            .environmentObject(ProfilePreviewFixtures.authManager())
    }
    .babloTheme(.normal)
}

#Preview("Profile · Needs Attention") {
    NavigationStack {
        ProfileView()
            .environmentObject(ProfilePreviewFixtures.userAccount())
            .environmentObject(ProfilePreviewFixtures.accountsService(.attention))
            .environmentObject(ProfilePreviewFixtures.plaidService())
            .environmentObject(ProfilePreviewFixtures.authManager())
    }
    .babloTheme(.normal)
}
#endif
