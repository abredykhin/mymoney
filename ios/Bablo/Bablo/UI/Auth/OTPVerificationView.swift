//
//  OTPVerificationView.swift
//  Bablo
//
//  Created for Phone Authentication with Supabase
//

import SwiftUI

struct OTPVerificationView: View {
    @StateObject private var phoneAuthService = PhoneAuthService()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccount: UserAccount

    let phoneNumber: String

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var resendCountdown: Int = 30
    @State private var canResend: Bool = false
    @State private var showError: Bool = false
    @State private var timer: Timer?

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "envelope.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)

                // Title
                Text("Enter Verification Code")
                    .font(.title2)
                    .fontWeight(.bold)

                // Subtitle
                Text("We sent a code to \(formattedPhoneNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // OTP Input Fields
                HStack(spacing: 12) {
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
                .padding(.horizontal, 20)

                // Loading Indicator
                if phoneAuthService.isLoading {
                    ProgressView()
                        .padding()
                }

                // Resend Button
                Button(action: resendCode) {
                    if canResend {
                        Text("Resend Code")
                            .foregroundColor(.accentColor)
                    } else {
                        Text("Resend in \(resendCountdown)s")
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!canResend || phoneAuthService.isLoading)
                .padding()

                // Disclaimer
                Text("Data rates may apply")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
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
                Text(phoneAuthService.errorMessage ?? "Invalid code. Please try again.")
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

    // MARK: - Helper Views

    private var formattedPhoneNumber: String {
        // Format +15551234567 as (555) 123-4567
        let cleaned = phoneNumber.replacingOccurrences(of: "+1", with: "")
        if cleaned.count == 10 {
            let areaCode = String(cleaned.prefix(3))
            let firstPart = String(cleaned.dropFirst(3).prefix(3))
            let secondPart = String(cleaned.suffix(4))
            return "(\(areaCode)) \(firstPart)-\(secondPart)"
        }
        return phoneNumber
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
            Logger.w("OTPVerificationView: Code incomplete")
            return
        }

        Logger.i("OTPVerificationView: Verifying code")

        Task {
            do {
                try await phoneAuthService.verifyCode(phoneNumber: phoneNumber, code: code)
                // Success! UserAccount will automatically update via auth state listener
                // Dismiss this view - the app will navigate to main screen automatically
                dismiss()
            } catch {
                Logger.e("OTPVerificationView: Verification failed: \(error)")
                showError = true
            }
        }
    }

    private func resendCode() {
        Logger.i("OTPVerificationView: Resending code")

        // Clear existing digits
        otpDigits = Array(repeating: "", count: 6)
        focusedField = 0

        Task {
            do {
                try await phoneAuthService.sendVerification(phoneNumber: phoneNumber)
                Logger.i("OTPVerificationView: Code resent successfully")
                startCountdown()
            } catch {
                Logger.e("OTPVerificationView: Failed to resend code: \(error)")
                showError = true
            }
        }
    }
}

// MARK: - OTP TextField Component

struct OTPTextField: View {
    @Binding var text: String
    @FocusState.Binding var focusedField: Int?
    let index: Int
    let onComplete: () -> Void

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.title)
            .frame(width: 45, height: 55)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedField == index ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .focused($focusedField, equals: index)
            .onChange(of: text) { _, newValue in
                // Only allow single digit
                if newValue.count > 1 {
                    text = String(newValue.prefix(1))
                }

                // Only allow digits
                if !newValue.isEmpty && !newValue.allSatisfy({ $0.isNumber }) {
                    text = ""
                    return
                }

                // Move to next field if digit entered
                if !newValue.isEmpty {
                    onComplete()
                }
            }
    }
}

#Preview {
    OTPVerificationView(phoneNumber: "+15551234567")
        .environmentObject(UserAccount.shared)
}
