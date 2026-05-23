//
//  WelcomeView.swift
//  Bablo
//

import SwiftUI

struct WelcomeView: View {
    @StateObject private var viewModel = BabloAuthViewModel()
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme
#if DEBUG
    @State private var showingOnboardingSandbox = false
#endif

    var body: some View {
        Group {
            switch viewModel.mode {
            case .landing:
                landing
            case .signIn, .signUp:
                EmailAuthView(mode: viewModel.mode) {
                    viewModel.mode = .landing
                }
                .environmentObject(userAccount)
            }
        }
#if DEBUG
        .fullScreenCover(isPresented: $showingOnboardingSandbox) {
            OnboardingSandboxView()
                .babloTheme(.normal)
        }
#endif
    }

    private var landing: some View {
        BabloScreenBackground {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: theme.effects.isPopArt ? 260 : 308)

                VStack(spacing: theme.effects.isPopArt ? 30 : 28) {
                    BabloLogoMark()

                    VStack(spacing: theme.effects.isPopArt ? 30 : 26) {
                        Text(BabloAuthMode.landing.title)
                            .font(landingTitleFont)
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: theme.effects.isPopArt ? 345 : 350)

                        Text(BabloAuthMode.landing.subtitle)
                            .font(landingSubtitleFont)
                            .foregroundStyle(theme.colors.textSecondary.color)
                            .multilineTextAlignment(.center)
                            .lineSpacing(theme.effects.isPopArt ? 2 : 6)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: theme.effects.isPopArt ? 322 : 328)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                VStack(spacing: theme.effects.isPopArt ? 16 : 22) {
                    Button {
                        viewModel.startSignUp()
                    } label: {
                        HStack(spacing: 10) {
                            Text(BabloAuthMode.landing.primaryActionTitle)
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(.babloPrimary)
                    .accessibilityIdentifier("auth.getStarted")

                    Button {
                        viewModel.startSignIn()
                    } label: {
                        Text(BabloAuthMode.landing.toggleTitle)
                            .font(landingToggleFont)
                            .foregroundStyle(theme.colors.textSecondary.color)
                            .textCase(theme.effects.isPopArt ? .uppercase : nil)
                            .tracking(theme.effects.isPopArt ? 2.4 : 0)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, theme.effects.isPopArt ? 54 : 0)
                    .accessibilityIdentifier("auth.alreadyHaveAccount")

#if DEBUG
                    Button {
                        showingOnboardingSandbox = true
                    } label: {
                        Text("Preview onboarding")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .textCase(theme.effects.isPopArt ? .uppercase : nil)
                            .tracking(theme.effects.isPopArt ? 1.8 : 0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("debug.previewOnboarding")
#endif
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            }
        }
    }

    private var landingTitleFont: Font {
        theme.effects.isPopArt
        ? .system(size: 30, weight: .black, design: .rounded).italic()
        : .system(size: 20, weight: .black, design: .default)
    }

    private var landingSubtitleFont: Font {
        theme.effects.isPopArt
        ? .system(size: 20, weight: .medium, design: .rounded)
        : .system(size: 16, weight: .regular, design: .default)
    }

    private var landingToggleFont: Font {
        theme.effects.isPopArt
        ? .system(size: 18, weight: .black, design: .rounded).italic()
        : .system(size: 16, weight: .bold, design: .default)
    }
}

#Preview("Welcome Pop") {
    WelcomeView()
        .environmentObject(UserAccount.shared)
        .babloTheme(.pop)
}

#Preview("Welcome Normal") {
    WelcomeView()
        .environmentObject(UserAccount.shared)
        .babloTheme(.normal)
}

#if DEBUG
#Preview("Welcome - Debug Onboarding Entry") {
    WelcomeView()
        .environmentObject(UserAccount.shared)
        .babloTheme(.normal)
}
#endif
