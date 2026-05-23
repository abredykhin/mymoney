import Testing
@testable import Bablo

@MainActor
struct OnboardingIncomeViewModelTests {

    // MARK: - Initial state

    @Test func initialStateIsZero() {
        let vm = IncomeInputViewModel()
        #expect(vm.rawDigits == "")
        #expect(vm.displayAmount == "$0")
        #expect(vm.intValue == 0)
    }

    // MARK: - Digit input

    @Test func appendingSingleDigit() {
        let vm = IncomeInputViewModel()
        vm.handleKey("5")
        #expect(vm.rawDigits == "5")
        #expect(vm.displayAmount == "$5")
        #expect(vm.intValue == 5)
    }

    @Test func appendingMultipleDigitsFormatsWithCommas() {
        let vm = IncomeInputViewModel()
        for d in ["5", "5", "8", "8"] { vm.handleKey(d) }
        #expect(vm.rawDigits == "5588")
        #expect(vm.displayAmount == "$5,588")
        #expect(vm.intValue == 5588)
    }

    @Test func leadingZeroIsIgnored() {
        let vm = IncomeInputViewModel()
        vm.handleKey("0")
        #expect(vm.rawDigits == "", "Leading zero should not be stored")
        #expect(vm.displayAmount == "$0")
    }

    @Test func zeroAfterNonZeroIsAllowed() {
        let vm = IncomeInputViewModel()
        vm.handleKey("1")
        vm.handleKey("0")
        vm.handleKey("0")
        #expect(vm.rawDigits == "100")
        #expect(vm.displayAmount == "$100")
    }

    // MARK: - Backspace

    @Test func backspaceOnSingleDigitClearsToEmpty() {
        let vm = IncomeInputViewModel()
        vm.handleKey("7")
        vm.handleKey("⌫")
        #expect(vm.rawDigits == "")
        #expect(vm.displayAmount == "$0")
    }

    @Test func backspaceOnMultipleDigitsRemovesLast() {
        let vm = IncomeInputViewModel()
        for d in ["1", "2", "3"] { vm.handleKey(d) }
        vm.handleKey("⌫")
        #expect(vm.rawDigits == "12")
        #expect(vm.displayAmount == "$12")
    }

    @Test func backspaceOnEmptyIsNoOp() {
        let vm = IncomeInputViewModel()
        vm.handleKey("⌫")
        #expect(vm.rawDigits == "")
        #expect(vm.displayAmount == "$0")
    }

    // MARK: - Max digits

    @Test func cannotExceedEightDigits() {
        let vm = IncomeInputViewModel()
        for d in ["1","2","3","4","5","6","7","8","9"] { vm.handleKey(d) }
        #expect(vm.rawDigits.count == 8)
        #expect(vm.intValue == 12_345_678)
    }

    // MARK: - Dot key is ignored (integers only)

    @Test func dotKeyIsIgnored() {
        let vm = IncomeInputViewModel()
        vm.handleKey("1")
        vm.handleKey(".")
        vm.handleKey("5")
        #expect(vm.rawDigits == "15")
    }

    // MARK: - Large number formatting

    @Test func millionFormatted() {
        let vm = IncomeInputViewModel()
        for d in ["1","0","0","0","0","0","0"] { vm.handleKey(d) }
        #expect(vm.displayAmount == "$1,000,000")
    }
}
