import SwiftUI
import LinkKit

enum OnboardingStep: CaseIterable, Identifiable {
    case welcome, budget, accounts
    var id: Self { self }
}

struct OnboardingWizard: View {
    @State private var currentStep: OnboardingStep = .welcome
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @EnvironmentObject var accountsService: AccountsService
    
    // Shared State
    @State private var income: String = "5500"
    @State private var expenses: String = "4300"
    @State private var isExpanded = false
    
    // Plaid Link State
    @StateObject var plaidService = PlaidService()
    @State private var shouldPresentLink = false
    @State private var linkController: LinkController? = nil
    @State private var isLoadingLinkToken = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSavingBudget = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                if currentStep != .welcome {
                    Button {
                        goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(height: 44)
            
            ZStack {
                switch currentStep {
                case .welcome:
                    OnboardingStartView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .budget:
                    OnboardingBudgetView(income: $income, expenses: $expenses)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .accounts:
                    OnboardingWalletView(isExpanded: $isExpanded)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut, value: currentStep)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer
            VStack(spacing: 12) {
                switch currentStep {
                case .welcome:
                    Button {
                        currentStep = .budget
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(100)
                            .shadow(color: Color(red: 0.4, green: 1.0, blue: 0.8).opacity(0.5), radius: 20, x: 0, y: 10)
                    }
                
                case .budget:
                    Button {
                        currentStep = .accounts
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.7, green: 1.0, blue: 0.0))
                            .cornerRadius(100)
                    }
                    
                    Button("Skip for now") {
                        currentStep = .accounts
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline.weight(.semibold))
                    
                case .accounts:
                    // Add Another Account Button pinned with Continue
                    if !accountsService.banksWithAccounts.isEmpty {
                        Button {
                            Task { await loadLinkToken() }
                        } label: {
                            HStack {
                                if isLoadingLinkToken {
                                    ProgressView().tint(.blue).padding(.trailing, 8)
                                }
                                Image(systemName: "plus")
                                Text("Add another account")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(100)
                        }
                    } else {
                        // Empty state: Connect with Plaid is the primary action
                        Button {
                            Task { await loadLinkToken() }
                        } label: {
                            HStack {
                                if isLoadingLinkToken {
                                    ProgressView().tint(.white).padding(.trailing, 8)
                                }
                                Image(systemName: "circle.grid.3x3.fill")
                                Text("Connect with Plaid")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.2, green: 0.6, blue: 0.4))
                            .cornerRadius(100)
                        }
                        .disabled(isLoadingLinkToken)
                    }
                    
                    // Final Continue Button
                    Button {
                        Task { await finishOnboarding() }
                    } label: {
                        HStack {
                            if isSavingBudget {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text("Continue")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(100)
                    }
                    .disabled(isSavingBudget)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $shouldPresentLink) {
            if let linkController {
                linkController.ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { showError = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func goBack() {
        withAnimation {
            switch currentStep {
            case .budget:
                currentStep = .welcome
            case .accounts:
                currentStep = .budget
            default:
                break
            }
        }
    }
    
    private func finishOnboarding() async {
        isSavingBudget = true
        defer { isSavingBudget = false }
        
        do {
            let inc = Double(income) ?? 0
            let exp = Double(expenses) ?? 0
            try await UserAccount.shared.updateProfileBudget(monthlyIncome: inc, monthlyExpenses: exp)
            
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            dismiss()
        } catch {
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func loadLinkToken() async {
        isLoadingLinkToken = true
        defer { isLoadingLinkToken = false }
        do {
            let linkToken = try await plaidService.createLinkToken()
            let config = try await generateLinkConfig(linkToken: linkToken)
            let handler = Plaid.create(config)
            switch handler {
            case .success(let handler):
                self.linkController = LinkController(handler: handler)
                self.shouldPresentLink = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func generateLinkConfig(linkToken: String) async throws -> LinkTokenConfiguration {
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Task {
                try? await plaidService.saveNewItem(publicToken: success.publicToken, institutionId: success.metadata.institution.id)
                try? await accountsService.refreshAccounts()
                self.shouldPresentLink = false
            }
        }
        config.onExit = { _ in self.shouldPresentLink = false }
        return config
    }
}

#Preview {
    OnboardingWizard()
        .environmentObject(AccountsService())
}
