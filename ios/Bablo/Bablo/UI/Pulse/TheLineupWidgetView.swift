import SwiftUI

// MARK: - Main Widget

struct TheLineupWidgetView: View {
    let items: [TopMerchantItem]
    var totalSpentOfPeriod: Double? = nil
    var isLoading: Bool = false
    var error: Error? = nil
    var retry: (() -> Void)? = nil
    var onAllTapped: (() -> Void)? = nil

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPopArt ? "THE LINEUP" : "The lineup")
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    if !items.isEmpty || (!isLoading && error == nil) {
                        Text("top \(items.count) · rings = % of the damage")
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
                        LineupRow(
                            rank: index + 1,
                            item: item,
                            totalSpentOfPeriod: totalSpentOfPeriod,
                            items: items,
                            theme: theme
                        )

                        if index < items.count - 1 {
                            Divider()
                                .overlay(theme.colors.line.color.opacity(0.6))
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
    let totalSpentOfPeriod: Double?
    let items: [TopMerchantItem]
    let theme: BabloResolvedTheme

    private var category: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil)
    }

    private var cleanMerchantName: String {
        var name = item.merchantName
        let suffixes = [" Coffee", " Inc.", " Inc", " Corp.", " Corp", " Ltd.", " Ltd", " LLC"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var iconEmoji: String {
        let name = item.merchantName.lowercased()
        if name.contains("blue bottle") { return "☕️" }
        if name.contains("trader joe") { return "🛒" }
        if name.contains("lyft") { return "🚗" }
        if name.contains("steam") { return "🎮" }
        if name.contains("sweetgreen") { return "🥗" }

        return category?.emoji ?? String(item.merchantName.prefix(1))
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

    private var totalSpent: Double {
        totalSpentOfPeriod ?? items.reduce(0.0) { $0 + $1.totalSpent }
    }

    private var percentage: Double {
        guard totalSpent > 0 else { return 0 }
        return (item.totalSpent / totalSpent) * 100
    }

    private var formattedPercentage: String {
        let pct = percentage
        let rounded = (pct * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))%"
        } else {
            return String(format: "%.1f%%", rounded)
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: item.totalSpent)) ?? "$0"
    }

    private var categoryLabel: String {
        let name = item.merchantName.lowercased()
        if name.contains("blue bottle") { return "Eats" }
        if name.contains("trader joe") { return "Groc" }
        if name.contains("lyft") { return "Trans" }
        if name.contains("steam") { return "Fun" }
        if name.contains("sweetgreen") { return "Eats" }

        let label = category?.shortName ?? "Other"
        if label == "Transit" { return "Trans" }
        return label
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(rank == 1 ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)
                .frame(width: 18, alignment: .leading)

            // Icon with progress ring
            ZStack {
                // Background Track
                Circle()
                    .stroke(theme.colors.lineStrong.color.opacity(0.4), lineWidth: 2)
                    .frame(width: 44, height: 44)

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(percentage / 100, 0), 1)))
                    .stroke(
                        barColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Inner Container
                Circle()
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)

                // Emoji
                Text(iconEmoji)
                    .font(.system(size: 18))
            }

            // Name + Category Info
            VStack(alignment: .leading, spacing: 4) {
                Text(cleanMerchantName)
                    .font(theme.typography.body(size: 15, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                Text("\(categoryLabel) · \(item.transactionCount)x")
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            // Amount + Percentage
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(theme.typography.body(size: 15, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .monospacedDigit()

                Text(formattedPercentage)
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }
        }
        .padding(.vertical, 12)
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
        TopMerchantItem(merchantName: "Blue Bottle Coffee", totalSpent: 39, transactionCount: 6, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Trader Joe's", totalSpent: 42, transactionCount: 1, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Lyft", totalSpent: 35, transactionCount: 4, personalFinanceCategory: "TRANSPORTATION"),
        TopMerchantItem(merchantName: "Steam", totalSpent: 30, transactionCount: 1, personalFinanceCategory: "ENTERTAINMENT"),
        TopMerchantItem(merchantName: "Sweetgreen", totalSpent: 28, transactionCount: 2, personalFinanceCategory: "FOOD_AND_DRINK"),
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
