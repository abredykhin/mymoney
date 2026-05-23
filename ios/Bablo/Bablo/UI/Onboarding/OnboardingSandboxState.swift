import Foundation

#if DEBUG
enum OnboardingSandboxScenario: CaseIterable, Identifiable {
    case empty
    case bankLinked

    var id: Self { self }

    var title: String {
        switch self {
        case .empty:      return "No data"
        case .bankLinked: return "Bank linked"
        }
    }
}

struct OnboardingSandboxState {
    private(set) var scenario: OnboardingSandboxScenario
    private(set) var currentStep: OnboardingStep = .name

    init(initialScenario: OnboardingSandboxScenario = .empty) {
        self.scenario = initialScenario
    }

    var hasLinkedBank: Bool {
        scenario == .bankLinked
    }

    mutating func setScenario(_ scenario: OnboardingSandboxScenario) {
        self.scenario = scenario
        if !hasLinkedBank && currentStep == .accountsConnected {
            currentStep = .linkBank
        }
    }

    mutating func advanceFromName() {
        currentStep = .income
    }

    mutating func advanceFromIncome() {
        currentStep = .linkBank
    }

    mutating func chooseManualEntry() {
        scenario = .empty
        currentStep = .fixedExpenses
    }

    mutating func finishFakePlaidLink() {
        scenario = .bankLinked
        currentStep = .accountsConnected
    }

    mutating func advance() {
        switch currentStep {
        case .name:
            currentStep = .income
        case .income:
            currentStep = .linkBank
        case .linkBank:
            currentStep = hasLinkedBank ? .accountsConnected : .fixedExpenses
        case .accountsConnected:
            currentStep = .fixedExpenses
        case .fixedExpenses:
            currentStep = .categories
        case .categories:
            break
        }
    }

    mutating func goBack() {
        switch currentStep {
        case .income:
            currentStep = .name
        case .linkBank:
            currentStep = .income
        case .accountsConnected:
            currentStep = .linkBank
        case .fixedExpenses:
            currentStep = hasLinkedBank ? .accountsConnected : .linkBank
        case .categories:
            currentStep = .fixedExpenses
        case .name:
            break
        }
    }
}
#endif
