import SwiftUI
import LinkKit

struct OnboardingWalletView: View {
    @EnvironmentObject var accountsService: AccountsService
    @Binding var isExpanded: Bool
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(Color.blue.opacity(0.1))
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
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Connect your accounts.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("We use Plaid to securely connect to 11,000+ financial institutions.")
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 40)
            
            // Bank Logo Stack (Simplified Mockup 1)
            ZStack {
                ForEach(0..<2) { index in
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white)
                        .frame(width: 260, height: 180)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .offset(y: CGFloat(index * 12))
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .zIndex(Double(-index))
                }
                
                VStack {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(0..<8) { _ in
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(20)
                    
                    Text("See everything in one place.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 260, height: 180)
            }
        }
    }
    
    private var walletState: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Wallet")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("\(accountsService.banksWithAccounts.count) bank(s) connected.")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if isExpanded {
                    Button {
                        withAnimation(.spring()) {
                            isExpanded = false
                        }
                    } label: {
                        Text("Collapse")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Stacked Account Cards
            ScrollView(showsIndicators: false) {
                let accounts = accountsService.banksWithAccounts.flatMap { bank in
                    bank.accounts.map { (bank, $0) }
                }
                
                if isExpanded {
                    VStack(spacing: 16) {
                        ForEach(Array(accounts.enumerated()), id: \.offset) { index, item in
                            OnboardingAccountCard(bank: item.0, account: item.1)
                        }
                    }
                    .padding(.bottom, 20)
                } else {
                    let displayAccounts = Array(accounts.prefix(3))
                    ZStack(alignment: .top) {
                        ForEach(Array(displayAccounts.enumerated()).reversed(), id: \.offset) { index, item in
                            OnboardingAccountCard(bank: item.0, account: item.1)
                                .zIndex(Double(displayAccounts.count - index))
                                .scaleEffect(1.0 - CGFloat(index) * 0.03)
                                .offset(y: CGFloat(index * 24)) // Peaking from bottom
                        }
                    }
                    .frame(height: 160 + CGFloat(min(displayAccounts.count, 3) - 1) * 24)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isExpanded = true
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

struct OnboardingAccountCard: View {
    let bank: Bank
    let account: BankAccount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bank.bank_name)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(account.iso_currency_code ?? "USD")
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            
            Text(account.name)
                .font(.system(size: 14))
                .opacity(0.9)
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.system(size: 10))
                        .opacity(0.7)
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code ?? "USD"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Spacer()
                if let mask = account.mask {
                    Text("•••• \(mask)")
                        .font(.system(size: 14))
                        .opacity(0.7)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background {
            let hex = bank.primary_color ?? "#000000"
            let color = Color(hex: hex)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.12), radius: 15, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    OnboardingWalletView(isExpanded: .constant(false))
        .environmentObject(AccountsService())
}
