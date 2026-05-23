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

    @Test func failedSendStoresErrorMessage() async {
        let sender = MockEmailSender(errorMessage: "Email service unavailable")
        let model = BabloAuthViewModel(mode: .signIn, emailSender: sender)
        model.email = "you@example.com"

        await model.sendCode()

        #expect(!model.showOTP)
        #expect(model.errorMessage == "Email service unavailable")
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
