import SwiftUI

// MARK: - Bar model

private struct EnergyBar: Identifiable {
    let id: String
    let label: String
    let amount: Double
    let isPeak: Bool
    let peakMerchant: String
    let peakAmount: Double
}

// MARK: - Main Widget

struct DailyEnergyWidgetView: View {
    let items: [DailyEnergyItem]
    let period: HeroPeriod
    var isLoading: Bool = false
    var error: Error? = nil
    var retry: (() -> Void)? = nil

    @Environment(\.babloTheme) private var theme

    private var bars: [EnergyBar] {
        switch period {
        case .day, .week:
            return items.map { item in
                EnergyBar(
                    id: item.weekday,
                    label: String(item.weekday.prefix(1)),
                    amount: item.totalSpent,
                    isPeak: item.isPeak,
                    peakMerchant: item.peakMerchant,
                    peakAmount: item.peakAmount
                )
            }
        case .month:
            return weeklyBars(from: items)
        }
    }

    private var avgPerDay: Double {
        let days = items.filter { $0.totalSpent > 0 }
        guard !days.isEmpty else { return 0 }
        return items.reduce(0) { $0 + $1.totalSpent } / Double(days.count)
    }

    private var peakBar: EnergyBar? {
        bars.first { $0.isPeak }
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            header(isPopArt: isPopArt)
            chartContent
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
        .accessibilityIdentifier("home.dailyEnergy")
    }

    private func header(isPopArt: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isPopArt ? "DAILY ENERGY" : "Daily energy")
                .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                .foregroundStyle(theme.colors.textPrimary.color)

            Group {
                if isLoading && items.isEmpty {
                    Text("Loading…")
                } else if avgPerDay > 0 {
                    Text("avg \(avgPerDay.formatted(.currency(code: "USD").precision(.fractionLength(0))))/day")
                } else {
                    Text("no spending this period")
                }
            }
            .font(theme.typography.body(size: 11, weight: .semibold))
            .foregroundStyle(theme.colors.textSecondary.color)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoading && items.isEmpty {
            ProgressView()
                .tint(theme.colors.textPrimary.color)
                .frame(maxWidth: .infinity, minHeight: 80)
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
            .frame(maxWidth: .infinity, minHeight: 80)
        } else if !bars.isEmpty {
            VStack(spacing: 8) {
                EnergyBarChart(bars: bars, theme: theme)

                if let peak = peakBar, peak.peakMerchant != "No Spend", peak.peakAmount > 0 {
                    PeakAnnotation(bar: peak, theme: theme)
                }
            }
        }
    }

    // MARK: - Month grouping

    private func weeklyBars(from items: [DailyEnergyItem]) -> [EnergyBar] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!

        struct WeekAccum {
            var total: Double = 0
            var peakAmount: Double = 0
            var peakMerchant: String = "No Spend"
        }

        var groups: [Int: WeekAccum] = [:]

        for item in items {
            guard let date = fmt.date(from: item.dateLabel) else { continue }
            let weekOfYear = cal.component(.weekOfYear, from: date)
            var acc = groups[weekOfYear] ?? WeekAccum()
            acc.total += item.totalSpent
            if item.peakAmount > acc.peakAmount {
                acc.peakAmount = item.peakAmount
                acc.peakMerchant = item.peakMerchant
            }
            groups[weekOfYear] = acc
        }

        let sortedKeys = groups.keys.sorted()
        let maxTotal = groups.values.map(\.total).max() ?? 0
        var peakAssigned = false

        return sortedKeys.enumerated().map { idx, key in
            let acc = groups[key]!
            let isPeak = !peakAssigned && acc.total == maxTotal && maxTotal > 0
            if isPeak { peakAssigned = true }
            return EnergyBar(
                id: "W\(idx + 1)",
                label: "W\(idx + 1)",
                amount: acc.total,
                isPeak: isPeak,
                peakMerchant: acc.peakMerchant,
                peakAmount: acc.peakAmount
            )
        }
    }
}

// MARK: - Bar Chart

private struct EnergyBarChart: View {
    let bars: [EnergyBar]
    let theme: BabloResolvedTheme

    private var maxAmount: Double {
        bars.map(\.amount).max() ?? 1
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(bars) { bar in
                    EnergyBarColumn(bar: bar, maxAmount: max(maxAmount, 1), theme: theme)
                }
            }
            .frame(height: 110)

            HStack(spacing: 4) {
                ForEach(bars) { bar in
                    Text(bar.label)
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .foregroundStyle(
                            bar.isPeak ? theme.colors.textPrimary.color : theme.colors.textTertiary.color
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct EnergyBarColumn: View {
    let bar: EnergyBar
    let maxAmount: Double
    let theme: BabloResolvedTheme

    private let maxBarHeight: CGFloat = 84

    private var barHeight: CGFloat {
        guard maxAmount > 0, bar.amount > 0 else { return 3 }
        return max(CGFloat(bar.amount / maxAmount) * maxBarHeight, 6)
    }

    private var barColor: Color {
        bar.isPeak ? theme.colors.accent.color : theme.colors.surfaceMuted.color
    }

    var body: some View {
        VStack(spacing: 3) {
            Spacer(minLength: 0)

            if bar.amount > 0 {
                Text(bar.amount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(theme.typography.mono(size: 9, weight: .semibold))
                    .foregroundStyle(
                        bar.isPeak ? theme.colors.textPrimary.color : theme.colors.textSecondary.color
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            } else {
                Color.clear.frame(height: 13)
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(barColor)
                .frame(height: barHeight)
                .overlay {
                    if theme.effects.isPopArt && bar.isPeak {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Peak Annotation

private struct PeakAnnotation: View {
    let bar: EnergyBar
    let theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: 8) {
            Text("PEAK")
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)

            Text("\(bar.label) · \(bar.peakMerchant)")
                .font(theme.typography.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)

            Spacer()

            Text(bar.peakAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                .font(theme.typography.mono(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if theme.effects.isPopArt {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.colors.lineStrong.color, lineWidth: 1)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG

private enum DailyEnergyPreviewFixtures {
    static let weekItems: [DailyEnergyItem] = [
        DailyEnergyItem(weekday: "Mon", dateLabel: "2026-05-18", totalSpent: 32, isPeak: false, peakMerchant: "Starbucks", peakCategory: nil, peakAmount: 18),
        DailyEnergyItem(weekday: "Tue", dateLabel: "2026-05-19", totalSpent: 64, isPeak: false, peakMerchant: "Whole Foods", peakCategory: nil, peakAmount: 42),
        DailyEnergyItem(weekday: "Wed", dateLabel: "2026-05-20", totalSpent: 18, isPeak: false, peakMerchant: "Uber", peakCategory: nil, peakAmount: 18),
        DailyEnergyItem(weekday: "Thu", dateLabel: "2026-05-21", totalSpent: 88, isPeak: false, peakMerchant: "Amazon", peakCategory: nil, peakAmount: 55),
        DailyEnergyItem(weekday: "Fri", dateLabel: "2026-05-22", totalSpent: 124, isPeak: true, peakMerchant: "Concert", peakCategory: nil, peakAmount: 124),
        DailyEnergyItem(weekday: "Sat", dateLabel: "2026-05-23", totalSpent: 41, isPeak: false, peakMerchant: "Grocery", peakCategory: nil, peakAmount: 41),
        DailyEnergyItem(weekday: "Sun", dateLabel: "2026-05-24", totalSpent: 20, isPeak: false, peakMerchant: "Netflix", peakCategory: nil, peakAmount: 20),
    ]

    static func monthItems() -> [DailyEnergyItem] {
        let calendar = Calendar(identifier: .iso8601)
        let base = DateFormatter()
        base.dateFormat = "yyyy-MM-dd"
        var items: [DailyEnergyItem] = []
        for day in 1...23 {
            let date = base.string(from: calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!)
            let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!) - 1]
            let short = String(weekday.prefix(3))
            let amount = Double.random(in: 0...120)
            items.append(DailyEnergyItem(weekday: short, dateLabel: date, totalSpent: amount, isPeak: false, peakMerchant: "Merchant", peakCategory: nil, peakAmount: amount * 0.7))
        }
        return items
    }
}

#Preview("Daily Energy · Week · Plain") {
    ScrollView {
        DailyEnergyWidgetView(items: DailyEnergyPreviewFixtures.weekItems, period: .week)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("Daily Energy · Week · Pop") {
    ScrollView {
        DailyEnergyWidgetView(items: DailyEnergyPreviewFixtures.weekItems, period: .week)
            .padding()
    }
    .babloScreenBackground()
    .babloTheme(.pop)
}

#Preview("Daily Energy · Month · Plain") {
    ScrollView {
        DailyEnergyWidgetView(items: DailyEnergyPreviewFixtures.monthItems(), period: .month)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("Daily Energy · Empty") {
    ScrollView {
        DailyEnergyWidgetView(items: [], period: .week, isLoading: false)
            .padding()
    }
    .babloScreenBackground()
}

#Preview("Daily Energy · Loading") {
    ScrollView {
        DailyEnergyWidgetView(items: [], period: .week, isLoading: true)
            .padding()
    }
    .babloScreenBackground()
}

#endif
