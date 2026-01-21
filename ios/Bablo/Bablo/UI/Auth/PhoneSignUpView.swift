//
//  PhoneSignUpView.swift
//  Bablo
//
//  Created for Phone Authentication with Supabase
//

import SwiftUI

struct PhoneSignUpView: View {
    @StateObject private var phoneAuthService = PhoneAuthService()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccount: UserAccount

    @State private var phoneNumber = ""
    @State private var formattedPhoneNumber = ""
    @State private var showOTPView = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "phone.circle.fill")
                    .font(Typography.displayLarge)
                    .foregroundColor(ColorPalette.primary)

                // Title
                Text("Sign Up with Phone")
                    .font(Typography.h3)
                    .fontWeight(.bold)

                // Subtitle
                Text("Enter your phone number to get started")
                    .font(Typography.bodyMedium)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)

                // Phone Number Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Phone Number")
                        .font(Typography.caption)
                        .foregroundColor(ColorPalette.textSecondary)

                    HStack {
                        Text("+1")
                            .foregroundColor(ColorPalette.textSecondary)
                            .padding(.leading, Spacing.md)

                        TextField("(555) 123-4567", text: $formattedPhoneNumber)
                            .keyboardType(.phonePad)
                            .onChange(of: formattedPhoneNumber) { _, newValue in
                                formatPhoneNumber(newValue)
                            }
                    }
                    .padding(Spacing.lg)
                    .background(ColorPalette.backgroundSecondary)
                    .cornerRadius(CornerRadius.textField)
                }
                .padding(.horizontal, Spacing.xxxl)

                // Send Code Button
                Button(action: sendCode) {
                    Text("Send Code")
                }
                .primaryButton(isLoading: phoneAuthService.isLoading, isDisabled: !isPhoneNumberValid)
                .padding(.horizontal, Spacing.xxxl)

                Spacer()
            }
            .padding(Spacing.lg)
            .navigationTitle("Sign Up")
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
                Text(phoneAuthService.errorMessage ?? "An error occurred")
            }
            .fullScreenCover(isPresented: $showOTPView) {
                OTPVerificationView(phoneNumber: toE164Format(phoneNumber))
                    .environmentObject(userAccount)
            }
        }
    }

    // MARK: - Helper Methods

    private var isPhoneNumberValid: Bool {
        // Remove all non-digits
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return digits.count == 10
    }

    private func formatPhoneNumber(_ input: String) {
        // Remove all non-digits
        let digits = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        phoneNumber = digits

        // Format as (XXX) XXX-XXXX
        var formatted = ""
        for (index, character) in digits.enumerated() {
            if index == 0 {
                formatted += "("
            } else if index == 3 {
                formatted += ") "
            } else if index == 6 {
                formatted += "-"
            }

            formatted += String(character)
        }

        // Limit to 10 digits
        if digits.count > 10 {
            phoneNumber = String(digits.prefix(10))
            return formatPhoneNumber(phoneNumber)
        }

        formattedPhoneNumber = formatted
    }

    private func toE164Format(_ number: String) -> String {
        // Remove all non-digits
        let digits = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return "+1\(digits)"
    }

    private func sendCode() {
        let e164Phone = toE164Format(phoneNumber)

        Task {
            do {
                try await phoneAuthService.sendVerification(phoneNumber: e164Phone)
                showOTPView = true
            } catch {
                Logger.e("PhoneSignUpView: Error sending code: \(error)")
                showError = true
            }
        }
    }
}

#Preview {
    PhoneSignUpView()
        .environmentObject(UserAccount.shared)
}
