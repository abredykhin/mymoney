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
    @EnvironmentObject var authManager: AuthManager
    
    // Shared State
    @State private var income: String = "5500"
    @State private var expenses: String = "4300"
    @State private var isExpanded = false

    // Plaid Link State
    @EnvironmentObject var plaidService: PlaidService
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
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(Typography.bodyMedium)
                        .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
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
            VStack(spacing: Spacing.md) {
                switch currentStep {
                case .welcome:
                    Button {
                        currentStep = .budget
                    } label: {
                        Text("Get Started")
                    }
                    .primaryButton()
                
                case .budget:
                    Button {
                        currentStep = .accounts
                    } label: {
                        Text("Continue")
                    }
                    .primaryButton()
                    
                    Button("Skip for now") {
                        currentStep = .accounts
                    }
                    .tertiaryButton()
                    
                case .accounts:
                    // Add Another Account Button pinned with Continue
                    if !accountsService.banksWithAccounts.isEmpty {
                        Button {
                            Task { await loadLinkToken() }
                        } label: {
                            HStack {
                                if isLoadingLinkToken {
                                    ProgressView().tint(ColorPalette.primary).padding(.trailing, Spacing.sm)
                                }
                                Image(systemName: "plus")
                                Text("Add another account")
                            }
                        }
                        .secondaryButton()
                    } else {
                        // Empty state: Connect with Plaid is the primary action
                        Button {
                            Task { await loadLinkToken() }
                        } label: {
                            HStack {
                                if isLoadingLinkToken {
                                    ProgressView().tint(.white).padding(.trailing, Spacing.sm)
                                }
                                Image(systemName: "circle.grid.3x3.fill")
                                Text("Connect with Plaid")
                            }
                        }
                        .primaryButton(isLoading: isLoadingLinkToken)
                    }
                    
                    // Final Continue Button
                    Button {
                        Task { await finishOnboarding() }
                    } label: {
                        HStack {
                            if isSavingBudget {
                                ProgressView().tint(.white).padding(.trailing, Spacing.sm)
                            }
                            Text("Continue")
                        }
                    }
                    .primaryButton(isLoading: isSavingBudget)
                }
            }
            .padding(.horizontal, Spacing.xxxl)
            .padding(.bottom, Spacing.lg)
        }
        .sheet(isPresented: $shouldPresentLink, onDismiss: {
            // Clear the handler when the sheet is dismissed
            // This prevents biometric auth from triggering during Plaid flow
            plaidService.currentHandler = nil

            // Update auth timestamp to prevent immediate auth prompt after Plaid flow
            authManager.recordSuccessfulAuthentication()
        }) {
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
                // Store handler in PlaidService for OAuth redirect handling
                self.plaidService.currentHandler = handler
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
            // Don't clear handler here - let the sheet's onDismiss handle it
            // This prevents biometric auth from triggering before sheet dismisses
            Task {
                try? await plaidService.saveNewItem(publicToken: success.publicToken, institutionId: success.metadata.institution.id)
                try? await accountsService.refreshAccounts()
                // Dismiss the sheet after saving the item
                await MainActor.run {
                    self.shouldPresentLink = false
                }
            }
        }
        config.onExit = { _ in
            // Dismiss the sheet - handler will be cleared in onDismiss
            self.shouldPresentLink = false
        }
        return config
    }
}

#Preview {
    OnboardingWizard()
        .environmentObject(AccountsService())
}
