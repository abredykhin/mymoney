import Testing
@testable import Bablo

@MainActor
struct OnboardingSandboxStateTests {
    @Test func emptyScenarioManualPathSkipsAccountsConnected() {
        var state = OnboardingSandboxState(initialScenario: .empty)

        #expect(state.currentStep == .name)
        #expect(state.hasLinkedBank == false)

        state.advanceFromName()
        #expect(state.currentStep == .income)

        state.advanceFromIncome()
        #expect(state.currentStep == .linkBank)

        state.chooseManualEntry()
        #expect(state.currentStep == .fixedExpenses)
        #expect(state.hasLinkedBank == false)
    }

    @Test func fakePlaidLinkShowsLinkedBankStateAndAccountsConnectedStep() {
        var state = OnboardingSandboxState(initialScenario: .empty)

        state.advanceFromName()
        state.advanceFromIncome()
        state.finishFakePlaidLink()

        #expect(state.currentStep == .accountsConnected)
        #expect(state.scenario == .bankLinked)
        #expect(state.hasLinkedBank == true)
    }

    @Test func linkedScenarioBackNavigationReturnsThroughAccountsConnected() {
        var state = OnboardingSandboxState(initialScenario: .bankLinked)

        state.advanceFromName()
        state.advanceFromIncome()
        state.finishFakePlaidLink()
        state.advance()
        #expect(state.currentStep == .fixedExpenses)

        state.goBack()
        #expect(state.currentStep == .accountsConnected)

        state.goBack()
        #expect(state.currentStep == .linkBank)
    }

    @Test func backNavigationFromIncomeReturnsToNameStep() {
        var state = OnboardingSandboxState(initialScenario: .empty)

        state.advanceFromName()
        #expect(state.currentStep == .income)

        state.goBack()
        #expect(state.currentStep == .name)
    }

    @Test func nameStepDoesNotShowBackButton() {
        #expect(!OnboardingStep.name.showsBackButton)
        #expect(OnboardingStep.income.showsBackButton)
    }
}
