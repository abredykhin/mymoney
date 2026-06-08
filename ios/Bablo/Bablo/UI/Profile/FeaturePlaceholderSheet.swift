//
//  FeaturePlaceholderSheet.swift
//  Bablo
//
//  Created for redesigned Profile page placeholders.
//

import SwiftUI

struct FeaturePlaceholderSheet: View {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let iconColor: Color
    
    @Environment(\.babloTheme) private var theme: BabloResolvedTheme
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.colors.appBackground.color
                .ignoresSafeArea()
                
            if theme.effects.isPopArt {
                theme.colors.pageBackground.color
                    .opacity(0.4)
                    .ignoresSafeArea()
            }

            VStack(spacing: Spacing.xl) {
                // Drag Indicator (if needed, but SwiftUI sheet has standard drag indicator)
                Spacer()
                    .frame(height: Spacing.sm)

                // Large Feature Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 84, height: 84)
                        
                    Image(systemName: systemImage)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(iconColor)
                }
                .padding(.top, Spacing.lg)

                // Title and Subtitle
                VStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(theme.typography.title(size: 26, weight: .bold))
                        .foregroundColor(theme.colors.textPrimary.color)
                        .multilineTextAlignment(.center)
                        
                    Text(subtitle)
                        .font(theme.typography.body(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.textSecondary.color)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.lg)

                // Main Description Card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Label("COMING SOON", systemImage: "sparkles")
                        .font(theme.typography.body(size: 11, weight: .black))
                        .foregroundColor(theme.colors.success.color)
                        .tracking(1.5)
                        
                    Text(description)
                        .font(theme.typography.body(size: 15, weight: .regular))
                        .foregroundColor(theme.colors.textPrimary.color)
                        .lineSpacing(4)
                }
                .babloCard(tone: .surface)
                .padding(.horizontal, Spacing.lg)

                Spacer()

                // Close Button
                Button(action: { dismiss() }) {
                    Text("Got it")
                        .font(theme.typography.body(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.babloPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .babloScreenBackground()
    }
}

#Preview("Placeholder Sheet Normal") {
    FeaturePlaceholderSheet(
        title: "Upgrade to Bablo+",
        subtitle: "Unlock unlimited goals and a smarter coach",
        description: "Bablo+ will give you tools to optimize your finances: track unlimited savings goals, receive direct notifications from our AI coach, and customize category weights for advanced cashflow projections.",
        systemImage: "star.fill",
        iconColor: Color.green
    )
    .babloTheme(.normal)
}

#Preview("Placeholder Sheet Pop") {
    FeaturePlaceholderSheet(
        title: "Security & privacy",
        subtitle: "Face ID and advanced data controls",
        description: "Secure your financial data with biometric locking and choose exactly which items and transaction scopes are shared with our optimization models.",
        systemImage: "shield.fill",
        iconColor: Color.blue
    )
    .babloTheme(.pop)
}
