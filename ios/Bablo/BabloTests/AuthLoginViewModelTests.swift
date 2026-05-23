//
//  AuthLoginViewModelTests.swift
//  BabloTests
//

import Testing
@testable import Bablo

@MainActor
struct AuthLoginViewModelTests {
    @Test func emailValidationAcceptsOrdinaryAddress() {
        let model = BabloAuthViewModel(emailSender: MockEmailSender())
        model.email = "you@example.com"

        #expect(model.isEmailValid)
    }

    @Test func emailValidationRejectsIncompleteAddress() {
        let model = BabloAuthViewModel(emailSender: MockEmailSender())
        model.email = "you@example"

        #expect(!model.isEmailValid)
    }

    @Test func sendCodeShowsOTPAfterSuccessfulSend() async {
        let sender = MockEmailSender()
        let model = BabloAuthViewModel(mode: .signIn, emailSender: sender)
        model.email = "you@example.com"

        await model.sendCode()

        #expect(sender.sentEmails == ["you@example.com"])
        #expect(model.showOTP)
        #expect(model.errorMessage == nil)
    }

    @Test func sendCodeSetsLoadingWhileRequestIsInFlight() async {
        let sender = SuspendedEmailSender()
        let model = BabloAuthViewModel(mode: .signIn, emailSender: sender)
        model.email = "you@example.com"

        let task = Task { await model.sendCode() }
        await sender.waitUntilStarted()

        #expect(model.isLoading)

        await sender.finish()
        await task.value
        #expect(!model.isLoading)
    }

    @Test func failedSendStoresErrorMessage() async {
        let sender = MockEmailSender(errorMessage: "Email service unavailable")
        let model = BabloAuthViewModel(mode: .signIn, emailSender: sender)
        model.email = "you@example.com"

        await model.sendCode()

        #expect(!model.showOTP)
        #expect(model.errorMessage == "Email service unavailable")
    }

    @Test func otpPasteFillsConsecutiveDigitsFromFocusedIndex() {
        var digits = Array(repeating: "", count: 6)

        let nextFocus = OTPCodeInput.apply("123456", to: &digits, startingAt: 0)

        #expect(digits == ["1", "2", "3", "4", "5", "6"])
        #expect(nextFocus == nil)
    }

    @Test func otpPasteIgnoresNonDigitsAndKeepsEarlierDigits() {
        var digits = ["9", "", "", "", "", ""]

        let nextFocus = OTPCodeInput.apply(" 12-34 ", to: &digits, startingAt: 1)

        #expect(digits == ["9", "1", "2", "3", "4", ""])
        #expect(nextFocus == 5)
    }
}

@MainActor
private final class MockEmailSender: EmailVerificationSending {
    var isLoading = false
    var errorMessage: String?
    var sentEmails: [String] = []

    init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }

    func sendVerification(email: String) async throws {
        if errorMessage != nil {
            throw MockEmailError.failed
        }

        sentEmails.append(email)
    }
}

private enum MockEmailError: Error {
    case failed
}

@MainActor
private final class SuspendedEmailSender: EmailVerificationSending {
    var isLoading = false
    var errorMessage: String?

    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var finishContinuation: CheckedContinuation<Void, Never>?

    func sendVerification(email: String) async throws {
        isLoading = true
        startedContinuation?.resume()
        startedContinuation = nil

        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }

        isLoading = false
    }

    func waitUntilStarted() async {
        if isLoading { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func finish() async {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}
