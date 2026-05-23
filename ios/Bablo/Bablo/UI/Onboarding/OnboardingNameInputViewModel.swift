import Foundation

@MainActor
@Observable
final class OnboardingNameInputViewModel {
    var firstName: String = ""

    var trimmedName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinue: Bool {
        !trimmedName.isEmpty
    }

    func chooseQuickName(_ name: String) {
        firstName = name
    }
}
