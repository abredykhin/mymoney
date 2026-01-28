import SwiftUI
import LinkKit

struct OnboardingWalletView: View {
    @EnvironmentObject var accountsService: AccountsService
    @Binding var isExpanded: Bool
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(ColorPalette.info.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(y: 100)

            VStack(spacing: 0) {
                if accountsService.banksWithAccounts.isEmpty {
                    connectState
                        .transition(.opacity)
                } else {
                    walletState
                        .transition(.opacity)
                }
                
                Spacer()
            }
        }
        .animation(.spring(), value: accountsService.banksWithAccounts.isEmpty)
        .animation(.spring(), value: isExpanded)
    }
    
    private var connectState: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.sm) {
                Text("Connect your accounts.")
                    .font(Typography.h1)
                    .multilineTextAlignment(.center)
                
                Text("We use Plaid to securely connect to 11,000+ financial institutions.")
                    .font(Typography.bodyLarge)
                    .multilineTextAlignment(.center)
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.xxxl)
            
            // Bank Logo Stack (Simplified Mockup 1)
            ZStack {
                ForEach(0..<2) { index in
                    RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                        .fill(ColorPalette.backgroundPrimary)
                        .frame(width: 260, height: 180)
                        .shadow(Elevation.level3)
                        .offset(y: CGFloat(index * 12))
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .zIndex(Double(-index))
                }
                
                VStack {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.lg) {
                        ForEach(0..<8) { _ in
                            Image(systemName: "building.columns.fill")
                                .font(Typography.h4)
                                .foregroundColor(ColorPalette.textSecondary.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(ColorPalette.backgroundSecondary)
                                .cornerRadius(CornerRadius.md)
                        }
                    }
                    .padding(Spacing.xl)
                    
                    Text("See everything in one place.")
                        .font(Typography.captionMedium)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .frame(width: 260, height: 180)
            }
        }
    }
    
    private var walletState: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your Wallet")
                        .font(Typography.h1)
                    
                    Text("\(accountsService.banksWithAccounts.count) bank(s) connected.")
                        .font(Typography.bodyLarge)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Spacer()
                
                if isExpanded {
                    Button {
                        withAnimation(.spring()) {
                            isExpanded = false
                        }
                    } label: {
                        Text("Collapse")
                            .font(Typography.captionBold)
                            .foregroundColor(ColorPalette.info)
                            .padding(.vertical, Spacing.sm)
                            .padding(.horizontal, Spacing.lg)
                            .background(ColorPalette.info.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            
            // Stacked Account Cards
            ScrollView(showsIndicators: false) {
                let accounts = accountsService.banksWithAccounts.flatMap { bank in
                    bank.accounts.map { (bank, $0) }
                }
                
                if isExpanded {
                    VStack(spacing: Spacing.lg) {
                        ForEach(Array(accounts.enumerated()), id: \.offset) { index, item in
                            OnboardingAccountCard(bank: item.0, account: item.1)
                        }
                    }
                    .padding(.bottom, Spacing.xl)
                } else {
                    let displayAccounts = Array(accounts.prefix(3))
                    ZStack(alignment: .top) {
                        ForEach(Array(displayAccounts.enumerated()).reversed(), id: \.offset) { index, item in
                            OnboardingAccountCard(bank: item.0, account: item.1)
                                .zIndex(Double(displayAccounts.count - index))
                                .scaleEffect(1.0 - CGFloat(index) * 0.03)
                                .offset(y: CGFloat(index) * Spacing.xl) // Peaking from bottom
                        }
                    }
                    .frame(height: 160 + CGFloat(min(displayAccounts.count, 3) - 1) * Spacing.xl)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isExpanded = true
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}

struct OnboardingAccountCard: View {
    let bank: Bank
    let account: BankAccount
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(bank.bank_name)
                    .font(Typography.bodySemibold)
                Spacer()
                Text(account.iso_currency_code ?? "USD")
                    .font(Typography.footnote)
                    .opacity(0.8)
            }
            
            Text(account.name)
                .font(Typography.caption)
                .opacity(0.9)
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Balance")
                        .font(Typography.footnote)
                        .opacity(0.7)
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                        .font(Typography.h3)
                }
                Spacer()
                if let mask = account.mask {
                    Text("•••• \(mask)")
                        .font(Typography.caption)
                        .opacity(0.7)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background {
            let hex = bank.primary_color ?? "#000000"
            let color = Color(hex: hex)
            RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                .fill(color ?? .black)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
        }
        .foregroundColor(.white)
        .shadow(Elevation.level4)
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.heroCard))
    }
}

#Preview {
    OnboardingWalletView(isExpanded: .constant(false))
        .environmentObject(AccountsService())
}
