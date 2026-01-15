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
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)

                // Title
                Text(isSignUp ? "Sign Up with Email" : "Sign In with Email")
                    .font(.title2)
                    .fontWeight(.bold)

                // Subtitle
                Text("Enter your email to \(isSignUp ? "get started" : "continue")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding()
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)

                // Send Code Button
                Button(action: sendCode) {
                    HStack {
                        if emailAuthService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isEmailValid ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isEmailValid || emailAuthService.isLoading)
                .padding(.horizontal, 40)

                // Toggle between Sign Up / Sign In
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
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
