//
//  EmailAuthView.swift
//  Bablo
//

import SwiftUI

struct EmailAuthView: View {
    @StateObject private var viewModel: BabloAuthViewModel
    @StateObject private var appleSignInCoordinator = SignInWithAppleCoordinator()
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme

    @State private var showError = false
    @State private var showGoogleUnavailable = false
    @FocusState private var isEmailFocused: Bool

    private let onBack: () -> Void

    init(mode: BabloAuthMode, onBack: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: BabloAuthViewModel(mode: mode))
        self.onBack = onBack
    }

    var body: some View {
        BabloScreenBackground {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        header
                        providerButtons
                        BabloAuthDivider()
                        emailForm
                        modeToggle
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, formTopPadding)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)

                Button {
                    Task { await viewModel.sendCode() }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(viewModel.mode.primaryActionTitle)
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(.babloPrimary)
                .disabled(!viewModel.canSubmitEmail)
                .accessibilityIdentifier("auth.primary")
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showOTP) {
            EmailOTPVerificationView(email: viewModel.email)
                .environmentObject(userAccount)
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? appleSignInCoordinator.errorMessage ?? "An unknown error occurred")
        }
        .alert("Google Sign-In Coming Soon", isPresented: $showGoogleUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple and email sign-in are ready now. Google needs provider configuration before it can be enabled.")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .onChange(of: appleSignInCoordinator.errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: headerTitleSpacing) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: theme.effects.isPopArt ? 25 : 20, weight: .black))
                    .frame(width: theme.effects.isPopArt ? 58 : 28, height: theme.effects.isPopArt ? 58 : 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.textPrimary.color)
            .background(theme.effects.isPopArt ? theme.colors.surfaceMuted.color : .clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? 4 : 0, style: .continuous))
            .overlay {
                if theme.effects.isPopArt {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                }
            }
            .accessibilityIdentifier("auth.back")

            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.mode.title)
                    .font(formTitleFont)
                    .tracking(theme.effects.isPopArt ? 2 : -1.5)
                    .textCase(theme.typography.isUppercaseDisplay ? .uppercase : nil)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(viewModel.mode.subtitle)
                    .font(.system(size: 15, weight: .regular, design: theme.effects.isPopArt ? .rounded : .default))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var providerButtons: some View {
        VStack(spacing: theme.effects.isPopArt ? 18 : 12) {
            BabloAuthProviderButton(provider: .apple) {
                appleSignInCoordinator.signInWithApple()
            }

            // TODO: Unhide when Google OAuth is configured
            if false {
                BabloAuthProviderButton(provider: .google) {
                    showGoogleUnavailable = true
                }
            }
        }
        .overlay {
            if appleSignInCoordinator.isLoading {
                ProgressView()
                    .padding(14)
                    .background(theme.colors.surface.color)
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
            }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: fieldSpacing) {
            TextField(
                text: $viewModel.email,
                prompt: Text("you\u{200B}@email.com").foregroundColor(theme.colors.textTertiary.color)
            ) {
                EmptyView()
            }
            .focused($isEmailFocused)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(theme.colors.textPrimary.color)
            .tint(theme.colors.textPrimary.color)
            .padding(.horizontal, 18)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("auth.email")
            .frame(minHeight: 52)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isEmailFocused ? theme.colors.textPrimary.color : theme.colors.line.color,
                        lineWidth: theme.metrics.borderWidth
                    )
            }

            if viewModel.mode == .signUp {
                Text("By continuing you agree to our Terms and Privacy Policy.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }

    private var modeToggle: some View {
        Button {
            viewModel.toggleAuthMode()
        } label: {
            Text(viewModel.mode.toggleTitle)
                .font(modeToggleFont)
                .tracking(theme.effects.isPopArt ? 1.6 : 0)
                .foregroundStyle(theme.colors.textSecondary.color)
                .textCase(theme.effects.isPopArt ? .uppercase : nil)
                .lineLimit(theme.effects.isPopArt ? 1 : 2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, toggleTopPadding)
        .accessibilityIdentifier("auth.toggleMode")
    }

    private var formTopPadding: CGFloat {
        theme.effects.isPopArt ? 84 : 16
    }

    private var contentSpacing: CGFloat {
        theme.effects.isPopArt ? 23 : 20
    }

    private var headerTitleSpacing: CGFloat {
        theme.effects.isPopArt ? 32 : 20
    }

    private var fieldSpacing: CGFloat {
        theme.effects.isPopArt ? 18 : 14
    }

    private var toggleTopPadding: CGFloat {
        viewModel.mode == .signUp ? (theme.effects.isPopArt ? 18 : 16) : (theme.effects.isPopArt ? 34 : 28)
    }

    private var formTitleFont: Font {
        theme.effects.isPopArt
        ? .system(size: 42, weight: .black, design: .rounded).italic()
        : .system(size: 26, weight: .black, design: .default)
    }

    private var modeToggleFont: Font {
        theme.effects.isPopArt
        ? .system(size: 16, weight: .black, design: .rounded).italic()
        : .system(size: 15, weight: .bold, design: .default)
    }
}

#Preview("Sign In Pop") {
    EmailAuthView(mode: .signIn)
        .environmentObject(UserAccount.shared)
        .babloTheme(.pop)
}

#Preview("Sign Up Normal") {
    EmailAuthView(mode: .signUp)
        .environmentObject(UserAccount.shared)
        .babloTheme(.normal)
}
