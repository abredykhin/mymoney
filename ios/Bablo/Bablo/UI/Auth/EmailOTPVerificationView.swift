//
//  EmailOTPVerificationView.swift
//  Bablo
//
//  Created for Email Authentication with Supabase
//

import SwiftUI

struct EmailOTPVerificationView: View {
    @StateObject private var emailAuthService = EmailAuthService()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccount: UserAccount

    let email: String

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var resendCountdown: Int = 30
    @State private var canResend: Bool = false
    @State private var showError: Bool = false
    @State private var timer: Timer?

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.xxl) {
                Spacer()

                // Icon
                Image(systemName: "envelope.fill")
                    .font(Typography.displayLarge)
                    .foregroundColor(ColorPalette.primary)

                // Title
                Text("Enter Verification Code")
                    .font(Typography.h3)
                    .fontWeight(.bold)

                // Subtitle
                Text("We sent a code to \(email)")
                    .font(Typography.bodyMedium)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)

                // OTP Input Fields
                HStack(spacing: Spacing.md) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPTextField(
                            text: $otpDigits[index],
                            focusedField: $focusedField,
                            index: index,
                            onComplete: {
                                if index < 5 {
                                    focusedField = index + 1
                                } else {
                                    // All digits entered, verify automatically
                                    focusedField = nil
                                    verifyCode()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.xl)

                // Loading Indicator
                if emailAuthService.isLoading {
                    ProgressView()
                        .padding(Spacing.lg)
                }

                // Resend Button
                Button(action: resendCode) {
                    if canResend {
                        Text("Resend Code")
                            .foregroundColor(ColorPalette.primary)
                    } else {
                        Text("Resend in \(resendCountdown)s")
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                .disabled(!canResend || emailAuthService.isLoading)
                .padding(Spacing.lg)

                // Disclaimer
                Text("Check your inbox and spam folder")
                    .font(Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)

                Spacer()
            }
            .padding(Spacing.lg)
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .alert("Verification Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    // Clear OTP fields on error
                    otpDigits = Array(repeating: "", count: 6)
                    focusedField = 0
                }
            } message: {
                Text(emailAuthService.errorMessage ?? "Invalid code. Please try again.")
            }
            .onAppear {
                startCountdown()
                // Auto-focus first field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = 0
                }
            }
            .onDisappear {
                stopCountdown()
            }
        }
    }

    // MARK: - Helper Methods

    private func startCountdown() {
        resendCountdown = 30
        canResend = false

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                canResend = true
                stopCountdown()
            }
        }
    }

    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
    }

    private func verifyCode() {
        let code = otpDigits.joined()

        guard code.count == 6 else {
            Logger.w("EmailOTPVerificationView: Code incomplete")
            return
        }

        Logger.i("EmailOTPVerificationView: Verifying code")

        Task {
            do {
                try await emailAuthService.verifyCode(email: email, code: code)
                // Success! UserAccount will automatically update via auth state listener
                // Dismiss this view - the app will navigate to main screen automatically
                dismiss()
            } catch {
                Logger.e("EmailOTPVerificationView: Verification failed: \(error)")
                showError = true
            }
        }
    }

    private func resendCode() {
        Logger.i("EmailOTPVerificationView: Resending code")

        // Clear existing digits
        otpDigits = Array(repeating: "", count: 6)
        focusedField = 0

        Task {
            do {
                try await emailAuthService.sendVerification(email: email)
                Logger.i("EmailOTPVerificationView: Code resent successfully")
                startCountdown()
            } catch {
                Logger.e("EmailOTPVerificationView: Failed to resend code: \(error)")
                showError = true
            }
        }
    }
}

#Preview {
    EmailOTPVerificationView(email: "test@example.com")
        .environmentObject(UserAccount.shared)
}
