import SwiftUI

// MARK: - Main Widget

struct TheLineupWidgetView: View {
    let items: [TopMerchantItem]
    var isLoading: Bool = false
    var error: Error? = nil
    var retry: (() -> Void)? = nil
    var onAllTapped: (() -> Void)? = nil

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let maxSpent = items.first?.totalSpent ?? 1

        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPopArt ? "THE LINEUP" : "The lineup")
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    if !items.isEmpty || (!isLoading && error == nil) {
                        Text("top \(items.count) merchants")
                            .font(theme.typography.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }

                Spacer()

                Button {
                    onAllTapped?()
                } label: {
                    HStack(spacing: 2) {
                        Text("All")
                            .font(theme.typography.body(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.colors.textSecondary.color)
                }
                .buttonStyle(.plain)
            }

            // Content
            if isLoading && items.isEmpty {
                ProgressView()
                    .tint(theme.colors.textPrimary.color)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if error != nil && items.isEmpty {
                VStack(spacing: 8) {
                    Text("Couldn't load merchants")
                        .font(theme.typography.body(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                    if let retry {
                        Button(action: retry) {
                            Label("Try again", systemImage: "arrow.clockwise")
                                .font(theme.typography.body(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if items.isEmpty {
                Text("No spending this period")
                    .font(theme.typography.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        LineupRow(rank: index + 1, item: item, maxSpent: maxSpent, theme: theme)

                        if index < items.count - 1 {
                            Divider()
                                .overlay(theme.colors.line.color.opacity(0.6))
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(
                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                )
        }
        .shadow(
            color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04),
            radius: isPopArt ? 0 : 16,
            x: isPopArt ? theme.effects.shadowX : 0,
            y: isPopArt ? theme.effects.shadowY : 6
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pulse.theLineup")
    }
}

// MARK: - Lineup Row

private struct LineupRow: View {
    let rank: Int
    let item: TopMerchantItem
    let maxSpent: Double
    let theme: BabloResolvedTheme

    private var category: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil)
    }

    private var iconEmoji: String {
        category?.emoji ?? String(item.merchantName.prefix(1))
    }

    private var iconBackground: Color {
        if let cat = category {
            return cat.barColor.opacity(0.15)
        }
        return theme.colors.surfaceMuted.color
    }

    private var barColor: Color {
        rank == 1 ? theme.colors.accent.color : theme.colors.textTertiary.color.opacity(0.35)
    }

    private var barFraction: Double {
        guard maxSpent > 0 else { return 0 }
        return item.totalSpent / maxSpent
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: item.totalSpent)) ?? "$0"
    }

    private var categoryLabel: String {
        category?.shortName ?? "Other"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(theme.typography.mono(size: 15, weight: .bold))
                .foregroundStyle(rank == 1 ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)
                .frame(width: 16, alignment: .center)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)

                Text(iconEmoji)
                    .font(.system(size: 20))
            }

            // Name + bar
            VStack(alignment: .leading, spacing: 5) {
                Text(item.merchantName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                GeometryReader { geo in
                    barColor
                        .frame(width: geo.size.width * barFraction, height: 3)
                        .clipShape(Capsule())
                }
                .frame(height: 3)
            }

            Spacer(minLength: 8)

            // Amount + count · category
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .monospacedDigit()

                Text("\(item.transactionCount)x · \(categoryLabel)")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Category bar color (reuse from WhereItWentWidgetView)

private extension FlexibleSpendingCategory {
    var barColor: Color {
        switch self {
        case .eatsOut:       return Color(red: 0.953, green: 0.482, blue: 0.416)
        case .coffeeRuns:    return Color(red: 0.961, green: 0.650, blue: 0.137)
        case .groceries:     return Color(red: 0.365, green: 0.725, blue: 0.365)
        case .fun:           return Color(red: 0.608, green: 0.349, blue: 0.714)
        case .shopping:      return Color(red: 0.914, green: 0.118, blue: 0.549)
        case .gettingAround: return Color(red: 0.290, green: 0.624, blue: 0.890)
        case .selfCare:      return Color(red: 0.969, green: 0.424, blue: 0.620)
        case .travel:        return Color(red: 0.110, green: 0.710, blue: 0.710)
        }
    }
}

// MARK: - Previews

#if DEBUG

private enum LineupPreviewFixtures {
    static let sampleItems: [TopMerchantItem] = [
        TopMerchantItem(merchantName: "Blue Bottle Coffee", totalSpent: 124, transactionCount: 6, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Trader Joe's", totalSpent: 98, transactionCount: 3, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Lyft", totalSpent: 71, transactionCount: 4, personalFinanceCategory: "TRANSPORTATION"),
        TopMerchantItem(merchantName: "Steam", totalSpent: 59, transactionCount: 2, personalFinanceCategory: "ENTERTAINMENT"),
        TopMerchantItem(merchantName: "Sweetgreen", totalSpent: 44, transactionCount: 3, personalFinanceCategory: "FOOD_AND_DRINK"),
    ]
}

#Preview("The Lineup · Plain") {
    ScrollView {
        TheLineupWidgetView(items: LineupPreviewFixtures.sampleItems)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("The Lineup · Pop") {
    ScrollView {
        TheLineupWidgetView(items: LineupPreviewFixtures.sampleItems)
            .padding()
    }
    .babloScreenBackground()
    .babloTheme(.pop)
}

#Preview("The Lineup · Loading") {
    ScrollView {
        TheLineupWidgetView(items: [], isLoading: true)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("The Lineup · Empty") {
    ScrollView {
        TheLineupWidgetView(items: [])
            .padding()
    }
    .babloScreenBackground()
}

#endif
