import SwiftUI

#if DEBUG
struct OnboardingSandboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.babloTheme) private var theme

    @State private var state: OnboardingSandboxState
    @State private var nameVM = OnboardingNameInputViewModel()
    @State private var incomeVM = IncomeInputViewModel()
    @State private var isLoadingLinkToken = false
    @StateObject private var accountsService: AccountsService

    init(initialScenario: OnboardingSandboxScenario = .empty) {
        let initialState = OnboardingSandboxState(initialScenario: initialScenario)
        _state = State(initialValue: initialState)
        _accountsService = StateObject(wrappedValue: initialScenario.accountsService)
    }

    var body: some View {
        ZStack {
            theme.colors.appBackground.color.ignoresSafeArea()

            VStack(spacing: 0) {
                SandboxTopBar(
                    step: state.currentStep,
                    onBack: goBack,
                    onClose: { dismiss() }
                )

                SandboxScenarioPicker(
                    selectedScenario: state.scenario,
                    onSelect: setScenario
                )
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.bottom, 8)

                ZStack {
                    switch state.currentStep {
                    case .name:
                        OnboardingNameView(
                            vm: nameVM,
                            isSaving: false,
                            onContinue: advanceFromName
                        )
                        .transition(stepTransition)

                    case .income:
                        OnboardingIncomeView(
                            vm: incomeVM,
                            userName: nameVM.trimmedName.isEmpty ? "Sam" : nameVM.trimmedName,
                            onContinue: advanceFromIncome,
                            onSkip: advanceFromIncome
                        )
                        .transition(stepTransition)

                    case .linkBank:
                        OnboardingLinkBankView(
                            isLoading: isLoadingLinkToken,
                            onLinkWithPlaid: startFakePlaidLink,
                            onManual: chooseManualEntry
                        )
                        .transition(stepTransition)

                    case .accountsConnected:
                        OnboardingAccountsConnectedView(
                            onLinkAnother: startFakePlaidLink,
                            onContinue: advance
                        )
                        .environmentObject(accountsService)
                        .transition(stepTransition)

                    case .fixedExpenses:
                        OnboardingFixedExpensesView { _ in
                            advance()
                        }
                        .transition(stepTransition)

                    case .categories:
                        OnboardingCategoriesView { _ in
                            dismiss()
                        }
                        .transition(stepTransition)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: state.currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }

    private func setScenario(_ scenario: OnboardingSandboxScenario) {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.setScenario(scenario)
            accountsService.banksWithAccounts = scenario.previewBanks
        }
    }

    private func advanceFromName() {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.advanceFromName()
        }
    }

    private func advanceFromIncome() {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.advanceFromIncome()
        }
    }

    private func chooseManualEntry() {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.chooseManualEntry()
            accountsService.banksWithAccounts = []
        }
    }

    private func startFakePlaidLink() {
        isLoadingLinkToken = true
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run {
                isLoadingLinkToken = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.finishFakePlaidLink()
                    accountsService.banksWithAccounts = OnboardingSandboxScenario.bankLinked.previewBanks
                }
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.advance()
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.goBack()
        }
    }
}

private struct SandboxTopBar: View {
    let step: OnboardingStep
    let onBack: () -> Void
    let onClose: () -> Void

    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            if step != .income {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Back")
            }

            BabloProgressPills(total: OnboardingStep.allCases.count, currentIndex: step.index)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Close onboarding preview")
        }
        .padding(.horizontal, theme.metrics.screenPadding)
        .padding(.vertical, 12)
        .frame(height: 44)
    }
}

private struct SandboxScenarioPicker: View {
    let selectedScenario: OnboardingSandboxScenario
    let onSelect: (OnboardingSandboxScenario) -> Void

    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingSandboxScenario.allCases) { scenario in
                Button {
                    onSelect(scenario)
                } label: {
                    Text(scenario.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(scenario == selectedScenario ? .white : theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            scenario == selectedScenario
                            ? theme.colors.textPrimary.color
                            : theme.colors.surface.color
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension OnboardingSandboxScenario {
    @MainActor
    var accountsService: AccountsService {
        switch self {
        case .empty:      return .onboardingPreviewEmpty
        case .bankLinked: return .onboardingPreviewLinkedBank
        }
    }

    var previewBanks: [Bank] {
        switch self {
        case .empty:      return []
        case .bankLinked: return Bank.onboardingPreviewBanks
        }
    }
}

#Preview("Onboarding Sandbox - Empty") {
    OnboardingSandboxView(initialScenario: .empty)
        .babloTheme(.normal)
}

#Preview("Onboarding Sandbox - Bank Linked") {
    OnboardingSandboxView(initialScenario: .bankLinked)
        .babloTheme(.normal)
}
#endif
