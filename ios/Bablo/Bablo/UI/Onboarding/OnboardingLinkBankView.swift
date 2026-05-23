import SwiftUI

struct OnboardingLinkBankView: View {
    let isLoading: Bool
    let onLinkWithPlaid: () -> Void
    let onManual: () -> Void

    @Environment(\.babloTheme) private var theme

    private let bankIcons = ["building.columns.fill", "building.2.fill",
                             "creditcard.fill", "banknote.fill", "heart.fill"]

    private let features: [(icon: String, title: String, detail: String)] = [
        ("bolt.fill",       "Instant setup",           "No spreadsheet, no math."),
        ("lock.fill",       "Bank-level security",     "256-bit encryption, read-only."),
        ("cpu.fill",        "AI does the boring work", "Categorizes & flags weird charges."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Bank icon row
            HStack(spacing: 10) {
                ForEach(bankIcons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(width: 52, height: 52)
                        .background(theme.colors.surface.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous))
                        .shadow(color: theme.effects.shadowColor.opacity(0.06), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, theme.metrics.screenPadding)

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("OPTIONAL")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(theme.typography.labelTracking)
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .padding(.top, 28)

                Text("Link your bank?")
                    .font(theme.typography.title(size: 34, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text("We auto-categorize your transactions so you don't have to. Read-only — we can't move your money.")
                    .font(theme.typography.body(size: 15))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenPadding)

            // Feature cards
            VStack(spacing: 10) {
                ForEach(features, id: \.title) { f in
                    HStack(spacing: 14) {
                        Image(systemName: f.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .frame(width: 40, height: 40)
                            .background(theme.colors.surfaceMuted.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                            Text(f.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.colors.textSecondary.color)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(theme.colors.surface.color)
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                }
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 24)

            Spacer()

            // Manual link
            Button(action: onManual) {
                Text("I'll add it manually")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .padding(.bottom, 14)

            OnboardingCTAButton(label: "Link with Plaid", isLoading: isLoading, action: onLinkWithPlaid)
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.bottom, 12)
        }
    }
}

#Preview {
    OnboardingLinkBankView(isLoading: false, onLinkWithPlaid: {}, onManual: {})
        .background(Color(hex: "#F8F5EF"))
}
