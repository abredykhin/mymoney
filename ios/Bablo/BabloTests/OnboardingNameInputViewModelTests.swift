import Testing
@testable import Bablo

@MainActor
struct OnboardingNameInputViewModelTests {
    @Test func emptyNameCannotContinue() {
        let vm = OnboardingNameInputViewModel()

        #expect(vm.firstName == "")
        #expect(vm.trimmedName == "")
        #expect(vm.canContinue == false)
    }

    @Test func whitespaceIsTrimmedForSavedName() {
        let vm = OnboardingNameInputViewModel()

        vm.firstName = "  Mia  "

        #expect(vm.trimmedName == "Mia")
        #expect(vm.canContinue == true)
    }

    @Test func quickNameSetsSelectedName() {
        let vm = OnboardingNameInputViewModel()

        vm.chooseQuickName("Jordan")

        #expect(vm.firstName == "Jordan")
        #expect(vm.trimmedName == "Jordan")
    }
}
