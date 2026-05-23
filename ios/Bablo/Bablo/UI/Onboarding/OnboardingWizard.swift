import SwiftUI
import LinkKit

enum OnboardingStep: CaseIterable, Identifiable {
    case income, linkBank, accountsConnected, fixedExpenses, categories
    var id: Self { self }

    var index: Int {
        switch self {
        case .income:             return 0
        case .linkBank:           return 1
        case .accountsConnected:  return 2
        case .fixedExpenses:      return 3
        case .categories:         return 4
        }
    }
}

struct OnboardingWizard: View {
    @State private var currentStep: OnboardingStep = .income
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var plaidService: PlaidService

    // Income
    @State private var incomeVM = IncomeInputViewModel()

    // Plaid
    @State private var shouldPresentLink = false
    @State private var linkController: LinkController?
    @State private var isLoadingLinkToken = false

    // Save state
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background via environment-aware wrapper
            ThemeBackground()

            VStack(spacing: 0) {
                // Top bar: back + progress
                OnboardingTopBar(
                    step: currentStep,
                    onBack: { withAnimation(.easeInOut(duration: 0.25)) { goBack() } }
                )

                // Step content
                ZStack {
                    switch currentStep {
                    case .income:
                        OnboardingIncomeView(
                            vm: incomeVM,
                            userName: UserAccount.shared.currentUser?.name ?? "there",
                            onContinue: { saveIncomeAndAdvance() },
                            onSkip: { advance() }
                        )
                        .transition(stepTransition)

                    case .linkBank:
                        OnboardingLinkBankView(
                            isLoading: isLoadingLinkToken,
                            onLinkWithPlaid: { Task { await loadLinkToken() } },
                            onManual: { advance() }
                        )
                        .transition(stepTransition)

                    case .accountsConnected:
                        OnboardingAccountsConnectedView(
                            onLinkAnother: { Task { await loadLinkToken() } },
                            onContinue: { advance() }
                        )
                        .transition(stepTransition)

                    case .fixedExpenses:
                        OnboardingFixedExpensesView { entries in
                            Task { await saveFixedExpensesAndAdvance(entries) }
                        }
                        .transition(stepTransition)

                    case .categories:
                        OnboardingCategoriesView { categories in
                            Task { await saveCategoriesAndFinish(categories) }
                        }
                        .transition(stepTransition)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $shouldPresentLink, onDismiss: {
            plaidService.currentHandler = nil
            authManager.recordSuccessfulAuthentication()
            // If they just linked a bank, jump to accounts-connected screen
            if !accountsService.banksWithAccounts.isEmpty {
                withAnimation { currentStep = .accountsConnected }
            }
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

    // MARK: - Sub-views

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch currentStep {
            case .income:            currentStep = .linkBank
            case .linkBank:          currentStep = accountsService.banksWithAccounts.isEmpty ? .fixedExpenses : .accountsConnected
            case .accountsConnected: currentStep = .fixedExpenses
            case .fixedExpenses:     currentStep = .categories
            case .categories:        break
            }
        }
    }

    private func goBack() {
        switch currentStep {
        case .linkBank:          currentStep = .income
        case .accountsConnected: currentStep = .linkBank
        case .fixedExpenses:     currentStep = accountsService.banksWithAccounts.isEmpty ? .linkBank : .accountsConnected
        case .categories:        currentStep = .fixedExpenses
        default:                 break
        }
    }

    // MARK: - Actions

    private func saveIncomeAndAdvance() {
        Task {
            guard incomeVM.intValue > 0 else { advance(); return }
            do {
                try await UserAccount.shared.updateProfileBudget(
                    monthlyIncome: Double(incomeVM.intValue),
                    monthlyExpenses: UserAccount.shared.profile?.monthlyMandatoryExpenses ?? 0
                )
            } catch {
                // Non-fatal: skip silently, data can be corrected in settings
            }
            advance()
        }
    }

    private func saveFixedExpensesAndAdvance(_ entries: [FixedExpenseEntry]) async {
        guard !entries.isEmpty else { advance(); return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await UserAccount.shared.saveFixedExpenses(entries)
        } catch {
            errorMessage = "Couldn't save expenses: \(error.localizedDescription)"
            showError = true
            return
        }
        advance()
    }

    private func saveCategoriesAndFinish(_ categories: [FlexibleSpendingCategory]) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await UserAccount.shared.updateTrackedCategories(categories.map(\.rawValue))
        } catch {
            // Non-fatal: proceed anyway
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }

    // MARK: - Plaid

    private func loadLinkToken() async {
        isLoadingLinkToken = true
        defer { isLoadingLinkToken = false }
        do {
            let token = try await plaidService.createLinkToken()
            let config = try await makeLinkConfig(token: token)
            let result = Plaid.create(config)
            switch result {
            case .success(let handler):
                plaidService.currentHandler = handler
                linkController = LinkController(handler: handler)
                shouldPresentLink = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func makeLinkConfig(token: String) async throws -> LinkTokenConfiguration {
        var config = LinkTokenConfiguration(token: token) { success in
            Task {
                try? await plaidService.saveNewItem(publicToken: success.publicToken, institutionId: success.metadata.institution.id)
                try? await accountsService.refreshAccounts()
                await MainActor.run { self.shouldPresentLink = false }
            }
        }
        config.onExit = { _ in shouldPresentLink = false }
        return config
    }
}

// MARK: - Top bar (separate struct to own @Environment cleanly)

private struct OnboardingTopBar: View {
    let step: OnboardingStep
    let onBack: () -> Void

    @SwiftUI.Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            if step != .income {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }

            BabloProgressPills(total: OnboardingStep.allCases.count, currentIndex: step.index)

            Spacer()
        }
        .padding(.horizontal, theme.metrics.screenPadding)
        .padding(.vertical, 12)
        .frame(height: 44)
    }
}

// MARK: - Background helper

private struct ThemeBackground: View {
    @SwiftUI.Environment(\.babloTheme) private var theme
    var body: some View {
        theme.colors.appBackground.color.ignoresSafeArea()
    }
}

#Preview {
    OnboardingWizard()
        .environmentObject(AccountsService())
        .environmentObject(PlaidService())
        .environmentObject(AuthManager.shared)
}
