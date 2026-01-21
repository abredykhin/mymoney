//
//  EmailAuthView.swift
//  Bablo
//
//  Created for Email Authentication with Supabase
//

import SwiftUI

struct EmailAuthView: View {
    @StateObject private var emailAuthService = EmailAuthService()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccount: UserAccount

    @State private var email = ""
    @State private var isSignUp = true
    @State private var showOTPView = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "envelope.circle.fill")
                    .font(Typography.displayLarge)
                    .foregroundColor(ColorPalette.primary)

                // Title
                Text(isSignUp ? "Sign Up with Email" : "Sign In with Email")
                    .font(Typography.h3)
                    .fontWeight(.bold)

                // Subtitle
                Text("Enter your email to \(isSignUp ? "get started" : "continue")")
                    .font(Typography.bodyMedium)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)

                // Email Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Email Address")
                        .font(Typography.caption)
                        .foregroundColor(ColorPalette.textSecondary)

                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(Spacing.lg)
                        .background(ColorPalette.backgroundSecondary)
                        .cornerRadius(CornerRadius.textField)
                }
                .padding(.horizontal, Spacing.xxxl)

                // Send Code Button
                Button(action: sendCode) {
                    Text("Send Code")
                }
                .primaryButton(isLoading: emailAuthService.isLoading, isDisabled: !isEmailValid)
                .padding(.horizontal, Spacing.xxxl)

                // Toggle between Sign Up / Sign In
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                        .font(Typography.bodyMedium)
                        .foregroundColor(ColorPalette.primary)
                }
                .padding(.top, Spacing.sm)

                Spacer()
            }
            .padding(Spacing.lg)
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(emailAuthService.errorMessage ?? "An error occurred")
            }
            .fullScreenCover(isPresented: $showOTPView) {
                EmailOTPVerificationView(email: email)
                    .environmentObject(userAccount)
            }
        }
    }

    // MARK: - Helper Methods

    private var isEmailValid: Bool {
        // Basic email validation
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func sendCode() {
        Task {
            do {
                try await emailAuthService.sendVerification(email: email)
                showOTPView = true
            } catch {
                Logger.e("EmailAuthView: Error sending code: \(error)")
                showError = true
            }
        }
    }
}

#Preview {
    EmailAuthView()
        .environmentObject(UserAccount.shared)
}
