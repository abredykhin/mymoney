//
//  BabloAuthViewModel.swift
//  Bablo
//

import Foundation

@MainActor
protocol EmailVerificationSending {
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func sendVerification(email: String) async throws
}

extension EmailAuthService: EmailVerificationSending {}

@MainActor
final class BabloAuthViewModel: ObservableObject {
    @Published var mode: BabloAuthMode
    @Published var email = ""
    @Published var showOTP = false
    @Published var errorMessage: String?

    private let emailSender: EmailVerificationSending

    init(mode: BabloAuthMode = .landing, emailSender: EmailVerificationSending? = nil) {
        self.mode = mode
        self.emailSender = emailSender ?? EmailAuthService()
    }

    var isEmailValid: Bool {
        let trimmedEmail = normalizedEmail
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return trimmedEmail.range(of: pattern, options: .regularExpression) != nil
    }

    var canSubmitEmail: Bool {
        isEmailValid && !emailSender.isLoading
    }

    var isLoading: Bool {
        emailSender.isLoading
    }

    func startSignUp() {
        mode = .signUp
    }

    func startSignIn() {
        mode = .signIn
    }

    func toggleAuthMode() {
        mode = mode == .signIn ? .signUp : .signIn
    }

    func sendCode() async {
        guard canSubmitEmail else { return }

        do {
            try await emailSender.sendVerification(email: normalizedEmail)
            showOTP = true
        } catch {
            errorMessage = emailSender.errorMessage ?? error.localizedDescription
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
