//
//  EmailOTPVerificationView.swift
//  Bablo
//

import SwiftUI

struct EmailOTPVerificationView: View {
    @StateObject private var emailAuthService = EmailAuthService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.babloTheme) private var theme

    let email: String

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var resendCountdown = 30
    @State private var canResend = false
    @State private var showError = false
    @State private var timer: Timer?

    var body: some View {
        BabloAuthShell {
            header
            otpFields
            resendSection
        } bottomBar: {
            Button {
                verifyCode()
            } label: {
                HStack(spacing: 10) {
                    if emailAuthService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Verify")
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(.babloPrimary)
            .disabled(!isCodeComplete || emailAuthService.isLoading)
            .accessibilityIdentifier("auth.verifyCode")
        }
        .alert("Verification Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {
                otpDigits = Array(repeating: "", count: 6)
                focusedField = 0
            }
        } message: {
            Text(emailAuthService.errorMessage ?? "Invalid code. Please try again.")
        }
        .onAppear {
            startCountdown()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = 0
            }
        }
        .onDisappear {
            stopCountdown()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 28) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .black))
            }
            .buttonStyle(.babloGhost)
            .accessibilityIdentifier("auth.otpBack")

            VStack(alignment: .leading, spacing: 14) {
                Text("Check your email.")
                    .font(theme.typography.display(size: 44, weight: .black))
                    .tracking(theme.typography.displayTracking)
                    .textCase(theme.typography.isUppercaseDisplay ? .uppercase : nil)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text("We sent a 6-digit code to \(email).")
                    .font(theme.typography.body(size: 20, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var otpFields: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                BabloOTPTextField(
                    text: $otpDigits[index],
                    focusedField: $focusedField,
                    index: index,
                    onComplete: {
                        if index < 5 {
                            focusedField = index + 1
                        } else {
                            focusedField = nil
                            verifyCode()
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var resendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: resendCode) {
                Text(canResend ? "Resend code" : "Resend in \(resendCountdown)s")
            }
            .buttonStyle(.babloGhost)
            .disabled(!canResend || emailAuthService.isLoading)
            .accessibilityIdentifier("auth.resendCode")

            Text("Check your inbox and spam folder.")
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
        }
    }

    private var isCodeComplete: Bool {
        otpDigits.joined().count == 6
    }

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
                dismiss()
            } catch {
                Logger.e("EmailOTPVerificationView: Verification failed: \(error)")
                showError = true
            }
        }
    }

    private func resendCode() {
        Logger.i("EmailOTPVerificationView: Resending code")

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

private struct BabloOTPTextField: View {
    @Binding var text: String
    @FocusState.Binding var focusedField: Int?
    let index: Int
    let onComplete: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(theme.typography.mono(size: 22, weight: .black))
            .foregroundStyle(theme.colors.textPrimary.color)
            .frame(width: 48, height: 58)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                    .stroke(
                        focusedField == index ? theme.colors.textPrimary.color : theme.colors.line.color,
                        lineWidth: focusedField == index ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                    )
            }
            .shadow(
                color: theme.effects.isPopArt ? theme.effects.shadowColor : .clear,
                radius: 0,
                x: theme.effects.isPopArt ? 3 : 0,
                y: theme.effects.isPopArt ? 3 : 0
            )
            .focused($focusedField, equals: index)
            .accessibilityIdentifier("auth.otp.\(index)")
            .onChange(of: text) { _, newValue in
                if newValue.count > 1 {
                    text = String(newValue.prefix(1))
                }

                if !newValue.isEmpty && !newValue.allSatisfy(\.isNumber) {
                    text = ""
                    return
                }

                if !newValue.isEmpty {
                    onComplete()
                }
            }
    }
}

#Preview("OTP Pop") {
    EmailOTPVerificationView(email: "test@example.com")
        .babloTheme(.pop)
}

#Preview("OTP Normal") {
    EmailOTPVerificationView(email: "test@example.com")
        .babloTheme(.normal)
}
