import SwiftUI

// MARK: - Bar Colors

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

extension SpendingBucket {
    var displayName: String {
        switch self {
        case .category(let cat): return cat.shortName
        case .rest: return "Rest"
        case .bills: return "Bills"
        }
    }

    var emoji: String {
        switch self {
        case .category(let cat): return cat.emoji
        case .rest: return "📦"
        case .bills: return "🧾"
        }
    }

    func barColor(theme: BabloResolvedTheme) -> Color {
        switch self {
        case .category(let cat): return cat.barColor
        case .rest: return theme.colors.textTertiary.color
        case .bills: return theme.colors.textSecondary.color
        }
    }

    func iconBackground(theme: BabloResolvedTheme) -> Color {
        switch self {
        case .category(let cat): return cat.barColor.opacity(0.15)
        case .rest: return theme.colors.surfaceMuted.color
        case .bills: return theme.colors.surfaceMuted.color
        }
    }
}

// MARK: - Main Widget

struct WhereItWentWidgetView: View {
    let items: [CategoryBreakdownItem]
    var isLoading: Bool = false
    var error: Error? = nil
    var retry: (() -> Void)? = nil
    var onItemTapped: ((CategoryBreakdownItem) -> Void)? = nil

    @State private var sortOrder: CategorySortOrder = .amount
    @Environment(\.babloTheme) private var theme

    private var sortedItems: [CategoryBreakdownItem] {
        var sorted = items

        switch sortOrder {
        case .amount:   sorted.sort { $0.totalAmount > $1.totalAmount }
        case .count:    sorted.sort { $0.transactionCount > $1.transactionCount }
        case .trending: sorted.sort { abs($0.trendPercent ?? 0) > abs($1.trendPercent ?? 0) }
        }

        return sorted
    }

    private var totalTransactionCount: Int {
        items.reduce(0) { $0 + $1.transactionCount }
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPopArt ? "WHERE IT WENT" : "Where it went")
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    if !items.isEmpty || (!isLoading && error == nil) {
                        Text("\(items.count) categories · \(totalTransactionCount) txns")
                            .font(theme.typography.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }

                Spacer()

                if !items.isEmpty {
                    Menu {
                        ForEach(CategorySortOrder.allCases) { order in
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { sortOrder = order }
                            } label: {
                                if sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Sort")
                                .font(theme.typography.body(size: 13, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }
            }

            // Stacked proportion bar
            if !items.isEmpty {
                CategoryStackedBar(items: sortedItems, theme: theme)
                    .frame(height: 8)
                    .clipShape(Capsule())
            }

            // Category rows / loading / error / empty
            if isLoading && items.isEmpty {
                ProgressView()
                    .tint(theme.colors.textPrimary.color)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if error != nil && items.isEmpty {
                VStack(spacing: 8) {
                    Text("Couldn't load spending")
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
                    ForEach(sortedItems) { item in
                        Button {
                            onItemTapped?(item)
                        } label: {
                            CategoryRow(item: item, theme: theme)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.id != sortedItems.last?.id {
                            Divider()
                                .overlay(theme.colors.line.color.opacity(0.6))
                                .padding(.leading, 56)
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
        .accessibilityIdentifier("pulse.whereItWent")
    }
}

// MARK: - Stacked Bar

private struct CategoryStackedBar: View {
    let items: [CategoryBreakdownItem]
    let theme: BabloResolvedTheme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isLast = index == items.count - 1
                    let width = max(geo.size.width * item.percentOfTotal - (isLast ? 0 : 2), 0)
                    item.bucket.barColor(theme: theme)
                        .frame(width: width)
                }
            }
        }
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let item: CategoryBreakdownItem
    let theme: BabloResolvedTheme

    private var trendColor: Color {
        switch item.isTrendUp {
        case true:  return theme.colors.danger.color
        case false: return theme.colors.success.color
        case nil:   return theme.colors.textTertiary.color
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with progress ring
            ZStack {
                // Background Track
                Circle()
                    .stroke(theme.colors.lineStrong.color.opacity(0.4), lineWidth: 2)
                    .frame(width: 44, height: 44)

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(item.percentOfTotal, 0), 1)))
                    .stroke(
                        item.bucket.barColor(theme: theme),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Inner Container
                Circle()
                    .fill(item.bucket.iconBackground(theme: theme))
                    .frame(width: 36, height: 36)

                // Emoji
                Text(item.bucket.emoji)
                    .font(.system(size: 18))
            }

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.bucket.displayName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                Text(item.transactionCount == 1 ? "1 txn" : "\(item.transactionCount) txns")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            // Amount + trend
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedAmount)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .monospacedDigit()

                if let trend = item.formattedTrend {
                    Text(trend)
                        .font(theme.typography.body(size: 11, weight: .semibold))
                        .foregroundStyle(trendColor)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Previews

#if DEBUG

private enum WhereItWentPreviewFixtures {
    static let sampleItems: [CategoryBreakdownItem] = [
        CategoryBreakdownItem(
            bucket: .category(.eatsOut), totalAmount: 142, transactionCount: 11,
            percentOfTotal: 0.37, previousAmount: 103
        ),
        CategoryBreakdownItem(
            bucket: .category(.gettingAround), totalAmount: 68, transactionCount: 7,
            percentOfTotal: 0.18, previousAmount: 74
        ),
        CategoryBreakdownItem(
            bucket: .category(.fun), totalAmount: 55, transactionCount: 4,
            percentOfTotal: 0.14, previousAmount: 49
        ),
        CategoryBreakdownItem(
            bucket: .category(.shopping), totalAmount: 48, transactionCount: 3,
            percentOfTotal: 0.12, previousAmount: 22
        ),
        CategoryBreakdownItem(
            bucket: .category(.groceries), totalAmount: 42, transactionCount: 2,
            percentOfTotal: 0.11, previousAmount: 44
        ),
        CategoryBreakdownItem(
            bucket: .rest, totalAmount: 32, transactionCount: 3,
            percentOfTotal: 0.08, previousAmount: 32
        ),
    ]
}

#Preview("Where It Went · Plain") {
    ScrollView {
        WhereItWentWidgetView(items: WhereItWentPreviewFixtures.sampleItems)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("Where It Went · Pop") {
    ScrollView {
        WhereItWentWidgetView(items: WhereItWentPreviewFixtures.sampleItems)
            .padding()
    }
    .babloScreenBackground()
    .babloTheme(.pop)
}

#Preview("Where It Went · Empty") {
    ScrollView {
        WhereItWentWidgetView(items: [])
            .padding()
    }
    .babloScreenBackground()
}

#endif
