import SwiftUI

struct BabloGoalCard: View {
    let title: String
    let iconName: String
    let subtitle: String?
    let currentAmount: Double
    let targetAmount: Double
    let weeklyChangeText: String?

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let progress = targetAmount > 0 ? min(1.0, max(0.0, currentAmount / targetAmount)) : 0.0

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                // Goal Icon Badge
                ZStack {
                    if isPopArt {
                        Rectangle()
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Rectangle()
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }

                // Text details
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(theme.typography.body(size: 15, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(theme.typography.body(size: 12, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                    }
                }

                Spacer()

                // Arrow indicator for detail view
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.top, 4)
            }

            // Progress Bar
            BabloProgressBar(progress: progress, height: isPopArt ? 12 : 8)
                .padding(.top, 2)

            // Balance Details Row
            HStack(alignment: .bottom) {
                HStack(spacing: 4) {
                    Text(formatCurrency(currentAmount))
                        .font(theme.typography.mono(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    Text("of \(formatCurrency(targetAmount))")
                        .font(theme.typography.body(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }

                Spacer()

                if let change = weeklyChangeText {
                    Text(change)
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(isPopArt ? theme.colors.textPrimary.color : theme.colors.textSecondary.color)
                }
            }
        }
        .babloCard(tone: .surface)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

#Preview("Goal Card Clean") {
    VStack {
        BabloGoalCard(
            title: "Japan trip",
            iconName: "airplane",
            subtitle: "ETA Aug 2026 · on track",
            currentAmount: 1720,
            targetAmount: 5000,
            weeklyChangeText: "+$84 this week"
        )
    }
    .padding()
    .babloTheme(.normal)
}

#Preview("Goal Card Pop") {
    VStack {
        BabloGoalCard(
            title: "Japan trip",
            iconName: "airplane",
            subtitle: "ETA Aug 2026 · on track",
            currentAmount: 1720,
            targetAmount: 5000,
            weeklyChangeText: "+$84 this week"
        )
    }
    .padding()
    .babloTheme(.pop)
}
