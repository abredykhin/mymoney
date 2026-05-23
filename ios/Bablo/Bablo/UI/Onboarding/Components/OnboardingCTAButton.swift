import SwiftUI

/// Full-width black CTA button with an arrow icon, used across all onboarding screens.
struct OnboardingCTAButton: View {
    let label: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.babloTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: theme.metrics.buttonHeight)
            .background(theme.colors.textPrimary.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
        }
        .disabled(isLoading)
    }
}
