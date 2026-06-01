import SwiftUI

// MARK: - Main Sheet

struct TheSwingSheetView: View {
    let report: PulseDamageReport
    let breakdown: [CategoryBreakdownItem]
    let dailyEnergy: [DailyEnergyItem]
    let period: PulsePeriod
    let dismissAction: () -> Void
    var onBreakdownCategoryTapped: ((CategoryBreakdownItem) -> Void)? = nil
    var onDayTapped: ((String, String, String, Double) -> Void)? = nil

    @Environment(\.babloTheme) private var theme

    private var delta: Double { report.spentDeltaFromPrevious ?? 0 }
    private var spentMore: Bool { delta >= 0 }
    private var previousTotal: Double { report.totalOut - delta }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(spacing: 0) {
            sheetHeader(isPopArt: isPopArt)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HeroComparisonCard(
                        report: report,
                        delta: delta,
                        spentMore: spentMore,
                        previousTotal: previousTotal,
                        period: period,
                        theme: theme
                    )

                    if !breakdownWithComparison.isEmpty {
                        CategorySwingCard(
                            delta: delta,
                            comparisonLabel: period.comparisonLabel,
                            items: breakdownWithComparison,
                            theme: theme,
                            onItemTapped: onBreakdownCategoryTapped
                        )
                    }

                    if !pairedDayBars.isEmpty {
                        DayByDaySwingCard(
                            bars: pairedDayBars,
                            period: period,
                            theme: theme,
                            onDayTapped: onDayTapped
                        )
                    }

                    if period == .month, !pairedWeekBars.isEmpty {
                        WeekByWeekSwingCard(
                            bars: pairedWeekBars,
                            theme: theme,
                            onWeekTapped: { weekStart, weekEnd, title, totalAmount in
                                onDayTapped?(weekStart, weekEnd, title, totalAmount)
                            }
                        )
                    }

                    if let verdict = verdictData {
                        TheVerdictCard(
                            verdict: verdict,
                            period: period,
                            theme: theme,
                            onBreakdownTapped: verdict.peakItem.flatMap { item in
                                onBreakdownCategoryTapped.map { cb in { cb(item) } }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .babloScreenBackground()
    }

    // MARK: - Header

    @ViewBuilder
    private func sheetHeader(isPopArt: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isPopArt ? period.swingPeriodLabel.uppercased() : period.swingPeriodLabel)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textTertiary.color)

                Text(isPopArt ? "THE SWING" : "The Swing")
                    .font(isPopArt
                          ? theme.typography.display(size: 28, weight: .black)
                          : theme.typography.title(size: 26, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text(period.swingSubtitle(report: report))
                    .font(theme.typography.body(size: 13, weight: .regular))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer()

            Button(action: dismissAction) {
                ZStack {
                    if isPopArt {
                        Rectangle()
                            .fill(theme.colors.surface.color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Rectangle()
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                            }
                            .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                    } else {
                        Circle()
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 36, height: 36)
                    }
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)

        Divider()
            .overlay(theme.colors.line.color)
    }

    // MARK: - Derived data

    private var breakdownWithComparison: [CategoryBreakdownItem] {
        breakdown.filter { $0.previousAmount != nil }
    }

    private var pairedDayBars: [SwingDayBar] {
        guard period == .week || period == .day else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo

        guard
            let currentStart = fmt.date(from: report.startDate),
            let currentEnd   = fmt.date(from: report.endDate)
        else { return [] }

        let cal = Calendar.bablo
        let prevStart: Date
        let prevEnd: Date
        switch period {
        case .day:
            prevStart = cal.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
            prevEnd   = cal.date(byAdding: .day, value: -1, to: currentEnd) ?? currentEnd
        case .week:
            prevStart = cal.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart
            prevEnd   = cal.date(byAdding: .day, value: -7, to: currentEnd) ?? currentEnd
        case .month:
            return []
        }

        let currentItems = dailyEnergy.filter {
            guard let d = fmt.date(from: $0.dateLabel) else { return false }
            return d >= currentStart && d <= currentEnd
        }.sorted { $0.dateLabel < $1.dateLabel }

        let previousItems = dailyEnergy.filter {
            guard let d = fmt.date(from: $0.dateLabel) else { return false }
            return d >= prevStart && d <= prevEnd
        }.sorted { $0.dateLabel < $1.dateLabel }

        guard !currentItems.isEmpty else { return [] }

        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        return currentItems.enumerated().map { idx, cur in
            let prev = idx < previousItems.count ? previousItems[idx] : nil
            let label = idx < dayLabels.count ? dayLabels[idx] : String(cur.weekday.prefix(1))
            let isPeak = cur.isPeak
            let spentMore = cur.totalSpent > (prev?.totalSpent ?? 0)
            return SwingDayBar(
                label: label,
                dateLabel: cur.dateLabel,
                currentAmount: cur.totalSpent,
                previousAmount: prev?.totalSpent ?? 0,
                isPeak: isPeak,
                peakLabel: isPeak && cur.peakMerchant != "No Spend" ? cur.peakMerchant : nil,
                spentMore: spentMore
            )
        }
    }

    private var pairedWeekBars: [SwingWeekBar] {
        guard period == .month else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo

        guard
            let currentStart = fmt.date(from: report.startDate),
            let currentEnd   = fmt.date(from: report.endDate)
        else { return [] }

        let cal = Calendar.bablo
        guard
            let prevStart = cal.date(byAdding: .month, value: -1, to: currentStart),
            let prevEnd   = cal.date(byAdding: .day, value: -1, to: currentStart)
        else { return [] }

        func getWeeks(forStart monthStart: Date, forEnd monthEnd: Date) -> [(weekStart: String, weekEnd: String, display: String, total: Double, peak: DailyEnergyItem?)] {
            var days: [Date] = []
            var currentDay = monthStart
            while currentDay <= monthEnd {
                days.append(currentDay)
                guard let next = cal.date(byAdding: .day, value: 1, to: currentDay) else { break }
                currentDay = next
            }

            var customCal = cal
            customCal.firstWeekday = 1 // Sunday-to-Saturday weeks

            let groupedByWeek = Dictionary(grouping: days) { date -> Date in
                customCal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            }

            let sortedWeekStarts = groupedByWeek.keys.sorted()

            return sortedWeekStarts.enumerated().map { index, weekStart in
                let weekDays = groupedByWeek[weekStart] ?? []
                let sortedWeekDays = weekDays.sorted()
                let wStart = sortedWeekDays.first ?? weekStart
                let wEnd = sortedWeekDays.last ?? weekStart

                let wStartStr = fmt.string(from: wStart)
                let wEndStr = fmt.string(from: wEnd)

                let monthName = wStart.monthName(calendar: customCal)
                let display: String
                if wStartStr == wEndStr {
                    display = "\(monthName) \(wStart.dayNumber(calendar: customCal))"
                } else {
                    display = "\(monthName) \(wStart.dayNumber(calendar: customCal))–\(wEnd.dayNumber(calendar: customCal))"
                }

                let weekItems = dailyEnergy.filter {
                    $0.dateLabel >= wStartStr && $0.dateLabel <= wEndStr
                }
                let total = weekItems.reduce(0.0) { $0 + $1.totalSpent }
                let peak = weekItems.max { $0.totalSpent < $1.totalSpent }

                return (wStartStr, wEndStr, display, total, peak)
            }
        }

        let currentWeeks = getWeeks(forStart: currentStart, forEnd: currentEnd)
        let previousWeeks = getWeeks(forStart: prevStart, forEnd: prevEnd)

        var bars: [SwingWeekBar] = []
        let weekLabels = ["W1", "W2", "W3", "W4", "W5", "W6"]

        for (idx, cur) in currentWeeks.enumerated() {
            let label = idx < weekLabels.count ? weekLabels[idx] : "W\(idx + 1)"
            let prev = idx < previousWeeks.count ? previousWeeks[idx] : nil

            let isPeak = dailyEnergy.max(by: { $0.totalSpent < $1.totalSpent })?.dateLabel == cur.peak?.dateLabel && cur.peak != nil

            bars.append(
                SwingWeekBar(
                    label: label,
                    weekStart: cur.weekStart,
                    weekEnd: cur.weekEnd,
                    title: cur.display,
                    currentAmount: cur.total,
                    previousAmount: prev?.total ?? 0,
                    isPeak: isPeak,
                    peakLabel: cur.peak?.peakMerchant != "No Spend" ? cur.peak?.peakMerchant : nil,
                    spentMore: cur.total > (prev?.total ?? 0)
                )
            )
        }

        return bars
    }

    private var verdictData: SwingVerdictData? {
        guard let delta = report.spentDeltaFromPrevious, abs(delta) > 0.01 else { return nil }

        let sorted = breakdownWithComparison.sorted {
            abs(($0.totalAmount - ($0.previousAmount ?? 0))) > abs(($1.totalAmount - ($1.previousAmount ?? 0)))
        }

        let topDrivers = Array(sorted.prefix(2))
        guard !topDrivers.isEmpty else { return nil }

        let totalDelta = abs(delta)
        let driverDelta = topDrivers.reduce(0.0) { sum, item in
            sum + abs(item.totalAmount - (item.previousAmount ?? item.totalAmount))
        }
        let driverPercent = totalDelta > 0 ? Int((driverDelta / totalDelta * 100).rounded()) : 0

        let peakDay: String?
        let peakDayAmount: Double?
        let peakDayDateLabel: String?
        if period == .month {
            let peakWeekBar = pairedWeekBars.max { $0.currentAmount < $1.currentAmount }
            peakDay = peakWeekBar.flatMap { "\($0.label)" }
            peakDayAmount = peakWeekBar?.currentAmount
            peakDayDateLabel = peakWeekBar?.weekStart
        } else {
            let peakBar = pairedDayBars.max { $0.currentAmount < $1.currentAmount }
            peakDay = peakBar?.peakLabel.map { "\($0)" }
            peakDayAmount = peakBar?.currentAmount
            peakDayDateLabel = peakBar?.dateLabel
        }

        return SwingVerdictData(
            spentMore: delta > 0,
            delta: delta,
            topDrivers: topDrivers,
            driverPercent: driverPercent,
            peakDay: peakDay,
            peakDayAmount: peakDayAmount,
            peakDayDateLabel: peakDayDateLabel,
            peakItem: sorted.first
        )
    }
}

// MARK: - Hero Comparison Card

private struct HeroComparisonCard: View {
    let report: PulseDamageReport
    let delta: Double
    let spentMore: Bool
    let previousTotal: Double
    let period: PulsePeriod
    let theme: BabloResolvedTheme

    private var percentChange: Int {
        guard previousTotal > 0.01 else { return 0 }
        return Int((abs(delta) / previousTotal * 100).rounded())
    }

    private var deltaColor: Color {
        spentMore ? theme.colors.danger.color : theme.colors.success.color
    }

    private var maxAmount: Double {
        max(report.totalOut, previousTotal, 1)
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(spentMore ? "YOU SPENT MORE" : "YOU SPENT LESS")
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textTertiary.color)

                HStack(alignment: .center) {
                    Text(formattedDelta)
                        .font(theme.typography.display(size: 46, weight: .heavy))
                        .foregroundStyle(deltaColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if percentChange > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: spentMore ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(percentChange) %")
                                .font(theme.typography.body(size: 14, weight: .bold))
                        }
                        .foregroundStyle(deltaColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(deltaColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            VStack(spacing: 10) {
                periodRow(
                    label: period.previousPeriodLabel,
                    dateRange: period.previousDateRangeLabel(report: report),
                    amount: previousTotal,
                    fillFraction: previousTotal / maxAmount,
                    isCurrent: false
                )

                periodRow(
                    label: period.currentPeriodLabel,
                    dateRange: period.currentDateRangeLabel(report: report),
                    amount: report.totalOut,
                    fillFraction: report.totalOut / maxAmount,
                    isCurrent: true
                )
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }

    private func periodRow(label: String, dateRange: String, amount: Double, fillFraction: Double, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(isCurrent ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)

                if !dateRange.isEmpty {
                    Text("· \(dateRange)")
                        .font(theme.typography.body(size: 12, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? theme.colors.textSecondary.color : theme.colors.textTertiary.color)
                }

                Spacer()

                Text(amount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(theme.typography.body(size: 16, weight: isCurrent ? .heavy : .bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textPrimary.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.colors.surfaceMuted.color)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isCurrent ? (spentMore ? theme.colors.danger.color : theme.colors.success.color) : theme.colors.textTertiary.color.opacity(0.35))
                        .frame(width: geo.size.width * CGFloat(min(fillFraction, 1.0)), height: 8)
                        .animation(.easeOut(duration: 0.4), value: fillFraction)
                }
            }
            .frame(height: 8)
        }
    }

    private var formattedDelta: String {
        let sign = spentMore ? "+" : "-"
        let amt = abs(delta).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        return "\(sign)\(amt)"
    }
}

// MARK: - Category Swing Card

private struct CategorySwingCard: View {
    let delta: Double
    let comparisonLabel: String
    let items: [CategoryBreakdownItem]
    let theme: BabloResolvedTheme
    var onItemTapped: ((CategoryBreakdownItem) -> Void)? = nil

    private var sortedItems: [CategoryBreakdownItem] {
        items.sorted {
            let d0 = $0.totalAmount - ($0.previousAmount ?? $0.totalAmount)
            let d1 = $1.totalAmount - ($1.previousAmount ?? $1.totalAmount)
            return abs(d0) > abs(d1)
        }
    }

    private var maxAbsDelta: Double {
        sortedItems.compactMap { item -> Double? in
            guard let prev = item.previousAmount else { return nil }
            return abs(item.totalAmount - prev)
        }.max() ?? 1
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let absTotal = abs(delta)
        let title = absTotal > 0.01
            ? "Where the \(absTotal.formatted(.currency(code: "USD").precision(.fractionLength(0)))) came from"
            : "Category breakdown"

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isPopArt ? title.uppercased() : title)
                    .font(theme.typography.title(size: 16, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text(comparisonLabel)
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            VStack(spacing: 0) {
                ForEach(sortedItems) { item in
                    CategorySwingRow(
                        item: item,
                        maxAbsDelta: maxAbsDelta,
                        theme: theme
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onItemTapped?(item) }

                    if item.id != sortedItems.last?.id {
                        Divider()
                            .overlay(theme.colors.line.color.opacity(0.6))
                    }
                }
            }

            HStack(spacing: 16) {
                legendItem(color: theme.colors.danger.color, label: "spent more")
                legendItem(color: theme.colors.success.color, label: "spent less")
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 8)
            Text(label)
                .font(theme.typography.body(size: 12, weight: .regular))
                .foregroundStyle(theme.colors.textTertiary.color)
        }
    }
}

private struct CategorySwingRow: View {
    let item: CategoryBreakdownItem
    let maxAbsDelta: Double
    let theme: BabloResolvedTheme

    private var previousAmount: Double { item.previousAmount ?? item.totalAmount }
    private var itemDelta: Double { item.totalAmount - previousAmount }
    private var spentMore: Bool { itemDelta > 0.005 }
    private var isFlat: Bool { abs(itemDelta) < 0.005 }
    private var barColor: Color { spentMore ? theme.colors.danger.color : theme.colors.success.color }
    private var barFraction: Double { min(abs(itemDelta) / max(maxAbsDelta, 1), 1.0) }

    private var deltaText: String {
        if isFlat { return "flat" }
        let sign = spentMore ? "+" : "-"
        return "\(sign)\(abs(itemDelta).formatted(.currency(code: "USD").precision(.fractionLength(0))))"
    }

    private var prevToCurrentText: String {
        "\(previousAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))→\(item.totalAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.bucket.iconBackground(theme: theme))
                    .frame(width: 36, height: 36)
                Text(item.bucket.emoji)
                    .font(.system(size: 18))
            }

            // Name + prev→current
            VStack(alignment: .leading, spacing: 2) {
                Text(item.bucket.displayName)
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text(prevToCurrentText)
                    .font(theme.typography.mono(size: 11, weight: .regular))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            // Diverging bar (left = less, right = more)
            HStack(spacing: 0) {
                // Left half: spent-less bar (right-aligned)
                ZStack(alignment: .trailing) {
                    Color.clear
                    if !spentMore && !isFlat {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barColor)
                            .frame(width: max(40 * CGFloat(barFraction), 4), height: 12)
                    }
                }
                .frame(width: 40, height: 12)

                // Center divider
                Rectangle()
                    .fill(theme.colors.line.color)
                    .frame(width: 1, height: 18)

                // Right half: spent-more bar (left-aligned)
                ZStack(alignment: .leading) {
                    Color.clear
                    if spentMore && !isFlat {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barColor)
                            .frame(width: max(40 * CGFloat(barFraction), 4), height: 12)
                    }
                }
                .frame(width: 40, height: 12)
            }
            .frame(width: 81, height: 18)

            // Delta label
            Text(deltaText)
                .font(theme.typography.body(size: 14, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isFlat ? theme.colors.textTertiary.color : barColor)
                .frame(width: 75, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Day By Day Card

private struct SwingDayBar: Identifiable {
    let id = UUID()
    let label: String
    let dateLabel: String
    let currentAmount: Double
    let previousAmount: Double
    let isPeak: Bool
    let peakLabel: String?
    let spentMore: Bool
}

private struct DayByDaySwingCard: View {
    let bars: [SwingDayBar]
    let period: PulsePeriod
    let theme: BabloResolvedTheme
    var onDayTapped: ((String, String, String, Double) -> Void)? = nil

    private var maxAmount: Double {
        bars.flatMap { [$0.currentAmount, $0.previousAmount] }.max() ?? 1
    }

    private var peakBar: SwingDayBar? {
        bars.max { $0.currentAmount < $1.currentAmount }
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isPopArt ? "DAY BY DAY" : "Day by day")
                    .font(theme.typography.title(size: 16, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text("ghost = last period")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            VStack(spacing: 6) {
                // Bars — peak label rendered inside each column
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(bars) { bar in
                        SwingBarColumn(
                            bar: bar,
                            maxAmount: max(maxAmount, 1),
                            theme: theme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDayTapped?(bar.dateLabel, bar.dateLabel, bar.dateLabel, bar.currentAmount)
                        }
                    }
                }
                .frame(height: 110)

                // Day labels
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }
}

private struct SwingBarColumn: View {
    let bar: SwingDayBar
    let maxAmount: Double
    let theme: BabloResolvedTheme

    private let maxBarHeight: CGFloat = 84

    private func barHeight(amount: Double) -> CGFloat {
        guard amount > 0 else { return 0 }
        return max(CGFloat(amount / maxAmount) * maxBarHeight, 4)
    }

    private var currentBarColor: Color {
        bar.spentMore ? theme.colors.danger.color : theme.colors.success.color
    }

    private var truncatedPeakLabel: String? {
        guard let label = bar.peakLabel else { return nil }
        if label.count > 12 {
            return String(label.prefix(10)) + "..."
        }
        return label
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Peak label sits directly on top of the tallest bar
            if bar.isPeak, let label = truncatedPeakLabel {
                Text(label)
                    .font(theme.typography.body(size: 10, weight: .bold))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .fixedSize()
                    .padding(.bottom, 4)
            }

            HStack(alignment: .bottom, spacing: 2) {
                // Current bar
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if bar.currentAmount > 0 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(currentBarColor)
                            .frame(height: barHeight(amount: bar.currentAmount))
                    }
                }

                // Ghost bar (previous period)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if bar.previousAmount > 0 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(height: barHeight(amount: bar.previousAmount))
                            .overlay {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(theme.colors.line.color, lineWidth: 0.5)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - The Verdict Card

private struct SwingVerdictData {
    let spentMore: Bool
    let delta: Double
    let topDrivers: [CategoryBreakdownItem]
    let driverPercent: Int
    let peakDay: String?
    let peakDayAmount: Double?
    let peakDayDateLabel: String?
    let peakItem: CategoryBreakdownItem?
}

private struct TheVerdictCard: View {
    let verdict: SwingVerdictData
    let period: PulsePeriod
    let theme: BabloResolvedTheme
    var onBreakdownTapped: (() -> Void)? = nil

    private var headlineText: String {
        let names = verdict.topDrivers.map { $0.bucket.displayName }
        let joined = names.count == 1 ? names[0] : "\(names[0]) & \(names[1])"
        if verdict.spentMore {
            return "\(joined) ran up the bill."
        } else {
            return "\(joined) kept things lean."
        }
    }

    private var bodyText: String {
        var parts: [String] = []

        if verdict.driverPercent > 0 {
            let deltaStr = abs(verdict.delta).formatted(.currency(code: "USD").precision(.fractionLength(0)))
            parts.append("They drove \(verdict.driverPercent)% of the \(verdict.spentMore ? "+" : "-")\(deltaStr).")
        }

        if let peak = verdict.peakDay, let amt = verdict.peakDayAmount {
            let amtStr = amt.formatted(.currency(code: "USD").precision(.fractionLength(0)))
            if period == .month {
                parts.append("\(peak) alone was \(amtStr) — your heaviest week.")
            } else {
                parts.append("\(peak) alone was \(amtStr) — your heaviest day.")
            }
        }

        return parts.joined(separator: " ")
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let accentBg: AnyShapeStyle = isPopArt
            ? AnyShapeStyle(theme.colors.accent.color)
            : AnyShapeStyle(LinearGradient(
                colors: [theme.colors.surface.color, theme.colors.accent.color.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.colors.accent.color)
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.accentInk.color)
                }

                Text("THE VERDICT")
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textTertiary.color)

                Spacer()
            }

            Text(headlineText)
                .font(theme.typography.title(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(theme.typography.body(size: 14, weight: .regular))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if onBreakdownTapped != nil {
                HStack(spacing: 12) {
                    if let tap = onBreakdownTapped {
                        Button(action: tap) {
                            HStack(spacing: 4) {
                                Text("Break it down")
                                    .font(theme.typography.body(size: 14, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(theme.colors.surface.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(theme.colors.textPrimary.color)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(accentBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(
                    isPopArt ? theme.colors.lineStrong.color : Color.clear,
                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : 0
                )
        }
    }
}

// MARK: - The Cushion Sheet

struct TheCushionSheetView: View {
    let snapshot: HeroCushionSnapshot
    let period: PulsePeriod
    let breakdown: [CategoryBreakdownItem]
    let dailyEnergy: [DailyEnergyItem]
    let isLoading: Bool
    let dismissAction: () -> Void
    let primaryAction: () -> Void

    @Environment(\.babloTheme) private var theme

    private var drivers: [HeroCushionDriver] {
        HeroCushionDriver.drivers(from: breakdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    CushionHeroComparisonCard(snapshot: snapshot, period: period, theme: theme)

                    if isLoading && drivers.isEmpty {
                        CushionLoadingCard(theme: theme)
                    } else if !drivers.isEmpty {
                        CushionDriversCard(
                            snapshot: snapshot,
                            period: period,
                            drivers: drivers,
                            theme: theme
                        )
                    }

                    if !cumulativePoints.isEmpty {
                        CushionPaceCard(
                            snapshot: snapshot,
                            points: cumulativePoints,
                            theme: theme
                        )
                    }

                    CushionVerdictCard(
                        snapshot: snapshot,
                        drivers: drivers,
                        theme: theme,
                        primaryAction: primaryAction,
                        secondaryAction: dismissAction
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .babloScreenBackground()
    }

    private var header: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(spacing: 0) {
            Capsule()
                .fill(theme.colors.line.color)
                .frame(width: 42, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPopArt ? period.swingPeriodLabel.uppercased() : period.swingPeriodLabel)
                        .font(theme.typography.mono(size: 11, weight: .bold))
                        .tracking(isPopArt ? 1.5 : 1.6)
                        .foregroundStyle(theme.colors.textTertiary.color)

                    Text(isPopArt ? "THE CUSHION" : "The Cushion")
                        .font(isPopArt
                              ? theme.typography.display(size: 28, weight: .black)
                              : theme.typography.title(size: 26, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    Text(period.cushionSubtitle)
                        .font(theme.typography.body(size: 13, weight: .regular))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }

                Spacer()

                Button(action: dismissAction) {
                    ZStack {
                        if isPopArt {
                            Rectangle()
                                .fill(theme.colors.surface.color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Rectangle()
                                        .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                                }
                                .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                        } else {
                            Circle()
                                .fill(theme.colors.surfaceMuted.color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Circle()
                                        .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                                }
                        }

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            Divider()
                .overlay(theme.colors.line.color)
        }
        .background(theme.colors.surface.color)
    }

    private var cumulativePoints: [CushionCumulativePoint] {
        CushionCumulativePoint.build(from: dailyEnergy, period: period)
    }
}

private struct CushionHeroComparisonCard: View {
    let snapshot: HeroCushionSnapshot
    let period: PulsePeriod
    let theme: BabloResolvedTheme

    private var accent: Color {
        if snapshot.currentRoom < 0 && snapshot.hasMoreRoom {
            return theme.colors.textSecondary.color
        }
        return snapshot.hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color
    }

    private var percentChange: Int {
        guard abs(snapshot.previousRoom) > 0.01 else { return 0 }
        return Int((abs(snapshot.roomDelta) / abs(snapshot.previousRoom) * 100).rounded())
    }

    private func calculateFillFraction(amount: Double, current: Double, previous: Double) -> Double {
        // amount, current, previous are spend values (always >= 0).
        // Higher spend = bigger bar; the period with the most spend gets fraction 1.0.
        let maxVal = max(current, previous)
        return maxVal > 0 ? amount / maxVal : 0.0
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CushionVerdictCopy.metricTitle(for: snapshot))
                        .font(theme.typography.mono(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.textTertiary.color)

                    Text(CushionVerdictCopy.metricAmount(for: snapshot))
                        .font(theme.typography.display(size: 46, weight: .heavy))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(accent)
                }

                Spacer()

                if percentChange > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.hasMoreRoom ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(percentChange) %")
                            .font(theme.typography.body(size: 14, weight: .bold))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            VStack(spacing: 10) {
                roomRow(
                    title: period.previousPeriodLabel,
                    dateRange: period.previousWindowLabel,
                    amount: snapshot.previousSpend,
                    isCurrent: false
                )

                roomRow(
                    title: period.currentPeriodLabel,
                    dateRange: period.currentWindowLabel,
                    amount: snapshot.currentSpend,
                    isCurrent: true
                )
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }

    private func roomRow(title: String, dateRange: String, amount: Double, isCurrent: Bool) -> some View {
        let isPopArt = theme.effects.isPopArt
        let rawFill = calculateFillFraction(amount: amount, current: snapshot.currentSpend, previous: snapshot.previousSpend)
        let fillFraction = max(0.08, min(rawFill, 1.0))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(isCurrent ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)

                Text("· \(dateRange)")
                    .font(theme.typography.body(size: 12, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(theme.colors.textTertiary.color)

                Spacer()

                Text(formattedMoney(amount))
                    .font(theme.typography.body(size: 16, weight: isCurrent ? .heavy : .bold))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? theme.colors.textPrimary.color : theme.colors.textSecondary.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.colors.surfaceMuted.color)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isCurrent ? accent : theme.colors.textTertiary.color.opacity(0.35))
                        .frame(width: geo.size.width * CGFloat(fillFraction), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct CushionDriversCard: View {
    let snapshot: HeroCushionSnapshot
    let period: PulsePeriod
    let drivers: [HeroCushionDriver]
    let theme: BabloResolvedTheme

    private var maxDelta: Double {
        drivers.map { abs($0.roomDelta) }.max() ?? 1
    }

    private var currentRoomColor: Color {
        if snapshot.currentRoom < 0 {
            return snapshot.hasMoreRoom ? theme.colors.textSecondary.color : theme.colors.danger.color
        }
        return snapshot.hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(snapshot.hasMoreRoom ? "How the room grew" : "How the room shrank")
                    .font(theme.typography.title(size: 16, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text(period.previousPeriodShortLabel + " → " + period.currentPeriodShortLabel)
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            HStack {
                Text(period.previousPeriodLabel)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textSecondary.color)

                Spacer()

                Text(formattedMoney(snapshot.previousRoom))
                    .font(theme.typography.body(size: 16, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            VStack(spacing: 10) {
                ForEach(drivers) { driver in
                    CushionDriverRow(driver: driver, maxDelta: maxDelta, theme: theme)
                }
            }

            Divider()
                .overlay(theme.colors.line.color)

            HStack {
                Text(period.currentPeriodLabel)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text(formattedMoney(snapshot.currentRoom))
                    .font(theme.typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(currentRoomColor)
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }
}

private struct CushionDriverRow: View {
    let driver: HeroCushionDriver
    let maxDelta: Double
    let theme: BabloResolvedTheme

    private var color: Color {
        driver.kind == .grew ? theme.colors.success.color : theme.colors.danger.color
    }

    private var barFraction: Double {
        min(abs(driver.roomDelta) / max(maxDelta, 1), 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(driver.bucket.iconBackground(theme: theme))
                    .frame(width: 36, height: 36)
                Text(driver.bucket.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.bucket.displayName)
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                Text(detailText)
                    .font(theme.typography.mono(size: 10, weight: .regular))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    Color.clear
                    if driver.kind == .shrank {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(width: max(40 * CGFloat(barFraction), 4), height: 12)
                    }
                }
                .frame(width: 40, height: 12)

                Rectangle()
                    .fill(theme.colors.line.color)
                    .frame(width: 1, height: 18)

                ZStack(alignment: .leading) {
                    Color.clear
                    if driver.kind == .grew {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(width: max(40 * CGFloat(barFraction), 4), height: 12)
                    }
                }
                .frame(width: 40, height: 12)
            }
            .frame(width: 81, height: 18)

            Text(formattedSigned(driver.roomDelta))
                .font(theme.typography.body(size: 14, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(color)
                .frame(width: 74, alignment: .trailing)
        }
    }

    private var detailText: String {
        return "\(driver.transactionCount)x · \(formattedMoney(driver.currentAmount))"
    }
}

private struct CushionPaceCard: View {
    let snapshot: HeroCushionSnapshot
    let points: [CushionCumulativePoint]
    let theme: BabloResolvedTheme

    private var maxValue: Double {
        points.flatMap { [$0.current, $0.previous] }.max() ?? 1
    }

    private var paceSummaryColor: Color {
        if snapshot.currentRoom < 0 && snapshot.hasMoreRoom {
            return theme.colors.textSecondary.color
        }
        return snapshot.hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let currentLabel: String
        let previousLabel: String
        switch snapshot.period {
        case .month: currentLabel = "This mo"; previousLabel = "Last mo"
        case .week:  currentLabel = "This wk"; previousLabel = "Last wk"
        case .day:   currentLabel = "Today";   previousLabel = "Yesterday"
        }
        let currentLineColor = snapshot.hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(snapshot.hasMoreRoom ? "You're spending slower" : "You're spending faster")
                    .font(theme.typography.title(size: 16, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text("cumulative spend")
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            CushionLineChart(points: points, maxValue: maxValue, hasMoreRoom: snapshot.hasMoreRoom, theme: theme)
                .frame(height: 166)

            HStack(spacing: 18) {
                legend(color: currentLineColor, label: currentLabel, dashed: false)
                legend(color: theme.colors.textTertiary.color, label: previousLabel, dashed: true)
                Spacer()
                Text(CushionVerdictCopy.paceSummary(for: snapshot))
                    .font(theme.typography.body(size: 13, weight: .bold))
                    .foregroundStyle(paceSummaryColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.75)
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }

    private func legend(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 8) {
            LineLegendMark(color: color, dashed: dashed)
                .frame(width: 24, height: 12)
            Text(label)
                .font(theme.typography.body(size: 12, weight: .regular))
                .foregroundStyle(theme.colors.textTertiary.color)
        }
    }
}

private struct CushionLineChart: View {
    let points: [CushionCumulativePoint]
    let maxValue: Double
    let hasMoreRoom: Bool
    let theme: BabloResolvedTheme

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                let top: CGFloat = 10
                let bottom: CGFloat = 24
                let height = max(size.height - top - bottom, 1)
                let width = max(size.width, 1)

                for fraction in [0.0, 0.5, 1.0] {
                    var grid = Path()
                    let y = top + height * CGFloat(fraction)
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: width, y: y))
                    ctx.stroke(grid, with: .color(theme.colors.line.color.opacity(0.75)), lineWidth: 1)
                }

                let previousPath = linePath(size: size, top: top, bottom: bottom, value: \.previous)
                let currentPath = linePath(size: size, top: top, bottom: bottom, value: \.current)

                // Fill area between lines first
                if !points.isEmpty {
                    var betweenPath = Path()
                    let firstPrev = chartPoint(amount: points[0].previous, index: 0, count: points.count, size: size, top: top, bottom: bottom)
                    betweenPath.move(to: firstPrev)

                    for index in 1..<points.count {
                        let p = chartPoint(amount: points[index].previous, index: index, count: points.count, size: size, top: top, bottom: bottom)
                        betweenPath.addLine(to: p)
                    }

                    let lastCurr = chartPoint(amount: points[points.count - 1].current, index: points.count - 1, count: points.count, size: size, top: top, bottom: bottom)
                    betweenPath.addLine(to: lastCurr)

                    for index in stride(from: points.count - 2, through: 0, by: -1) {
                        let p = chartPoint(amount: points[index].current, index: index, count: points.count, size: size, top: top, bottom: bottom)
                        betweenPath.addLine(to: p)
                    }
                    betweenPath.closeSubpath()

                    let fillColors: [Color] = hasMoreRoom ? [
                        theme.colors.success.color.opacity(0.24),
                        theme.colors.success.color.opacity(0.02)
                    ] : [
                        theme.colors.danger.color.opacity(0.24),
                        theme.colors.danger.color.opacity(0.02)
                    ]

                    ctx.fill(
                        betweenPath,
                        with: .linearGradient(
                            Gradient(colors: fillColors),
                            startPoint: CGPoint(x: 0, y: top),
                            endPoint: CGPoint(x: 0, y: top + height)
                        )
                    )
                }

                ctx.stroke(
                    previousPath,
                    with: .color(theme.colors.textTertiary.color.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round, dash: [5, 5])
                )
                ctx.stroke(
                    currentPath,
                    with: .color(hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color),
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
                )
            }
            .overlay {
                GeometryReader { geo in
                    if let last = points.last {
                        let previous = point(for: last.previous, index: points.count - 1, size: geo.size)
                        let current = point(for: last.current, index: points.count - 1, size: geo.size)

                        Circle()
                            .stroke(theme.colors.textTertiary.color, lineWidth: 2)
                            .background(Circle().fill(theme.colors.surface.color))
                            .frame(width: 9, height: 9)
                            .position(previous)

                        Circle()
                            .fill(hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color)
                            .frame(width: 10, height: 10)
                            .position(current)
                    }
                }
            }

            HStack {
                ForEach(points) { point in
                    Text(point.label)
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func linePath(size: CGSize, top: CGFloat, bottom: CGFloat, value: KeyPath<CushionCumulativePoint, Double>) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, item) in points.enumerated() {
            let point = chartPoint(amount: item[keyPath: value], index: index, count: points.count, size: size, top: top, bottom: bottom)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func point(for amount: Double, index: Int, size: CGSize) -> CGPoint {
        chartPoint(amount: amount, index: index, count: points.count, size: size, top: 10, bottom: 24)
    }

    private func chartPoint(amount: Double, index: Int, count: Int, size: CGSize, top: CGFloat, bottom: CGFloat) -> CGPoint {
        let width = max(size.width, 1)
        let height = max(size.height - top - bottom, 1)
        let x = count <= 1 ? 0 : width * CGFloat(index) / CGFloat(count - 1)
        let y = top + height * CGFloat(1 - min(max(amount / max(maxValue, 1), 0), 1))
        return CGPoint(x: x, y: y)
    }
}

private struct LineLegendMark: View {
    let color: Color
    let dashed: Bool

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 1, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 1, y: size.height / 2))
            ctx.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: dashed ? [4, 4] : [])
            )
        }
    }
}

private struct CushionVerdictCard: View {
    let snapshot: HeroCushionSnapshot
    let drivers: [HeroCushionDriver]
    let theme: BabloResolvedTheme
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    private var accent: Color {
        snapshot.hasMoreRoom ? theme.colors.accent.color : theme.colors.danger.color.opacity(0.14)
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.colors.accent.color)
                        .frame(width: 36, height: 36)
                    Image(systemName: "scope")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.accentInk.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(CushionVerdictCopy.eyebrow(for: snapshot))
                        .font(theme.typography.mono(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.textPrimary.color.opacity(0.82))

                    Text(headline)
                        .font(theme.typography.title(size: 18, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(bodyText)
                .font(theme.typography.body(size: 14, weight: .regular))
                .foregroundStyle(theme.colors.textSecondary.color)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 48)

            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    HStack(spacing: 4) {
                        Text(CushionVerdictCopy.primaryButtonTitle(for: snapshot))
                            .font(theme.typography.body(size: 14, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: secondaryAction) {
                    Text("Let it ride")
                        .font(theme.typography.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.colors.surface.color.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 48)
        }
        .padding(16)
        .background(
            isPopArt
            ? AnyShapeStyle(theme.colors.accent.color)
            : AnyShapeStyle(LinearGradient(
                colors: [theme.colors.surface.color, accent.opacity(0.28), theme.colors.surface.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(
                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color.opacity(0.55),
                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                )
        }
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }

    private var headline: String {
        CushionVerdictCopy.headline(for: snapshot, comparisonName: comparisonName)
    }

    private var bodyText: String {
        let names = drivers.prefix(2).map { $0.bucket.displayName.lowercased() }
        let driverText = names.isEmpty ? "A few small choices" : names.joined(separator: " and ")
        if snapshot.currentRoom < 0 {
            if snapshot.roomDelta >= 0 {
                return "\(driverText.capitalized) helped, but this week is still over. Keep the next flexible buys tight."
            }
            return "\(driverText.capitalized) did most of it. Pull back on the next flexible buys so the week can recover."
        } else if snapshot.hasMoreRoom {
            return "\(driverText.capitalized) did most of it. Stash the extra room before the weekend quietly spends it."
        }
        return "\(driverText.capitalized) did most of it. Trim the next couple of flexible buys and the cushion can recover."
    }

    private var comparisonName: String {
        switch snapshot.period {
        case .day: return "yesterday"
        case .week: return "last week"
        case .month: return "last month"
        }
    }
}

enum CushionVerdictCopy {
    static func metricTitle(for snapshot: HeroCushionSnapshot) -> String {
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0 ? "LESS IN THE RED" : "DEEPER IN THE RED"
        }
        return snapshot.hasMoreRoom ? "MORE TO SPEND" : "LESS TO SPEND"
    }

    static func metricAmount(for snapshot: HeroCushionSnapshot) -> String {
        if snapshot.currentRoom < 0 {
            return formattedMoney(abs(snapshot.roomDelta))
        }
        return formattedSigned(snapshot.roomDelta)
    }

    static func paceSummary(for snapshot: HeroCushionSnapshot) -> String {
        let amount = formattedMoney(abs(snapshot.roomDelta))
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0 ? "\(amount) better by Sunday" : "\(amount) deeper by Sunday"
        }
        return "\(amount) \(snapshot.hasMoreRoom ? "under" : "over") by Sunday"
    }

    static func eyebrow(for snapshot: HeroCushionSnapshot) -> String {
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0 ? "KEEP CLIMBING OUT" : "KEEP THE LEAK CONTAINED"
        }
        return snapshot.hasMoreRoom ? "MAKE THE SURPLUS COUNT" : "KEEP THE LEAK CONTAINED"
    }

    static func headline(for snapshot: HeroCushionSnapshot, comparisonName: String) -> String {
        let amount = formattedMoney(abs(snapshot.roomDelta))
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0
                ? "Still over, but better than \(comparisonName)."
                : "Deeper in the red than \(comparisonName)."
        }
        if snapshot.hasMoreRoom {
            return "You're \(amount) ahead of \(comparisonName)."
        }
        return "You're \(amount) tighter than \(comparisonName)."
    }

    static func primaryButtonTitle(for snapshot: HeroCushionSnapshot) -> String {
        if snapshot.currentRoom < 0 || !snapshot.hasMoreRoom {
            return "Review spend"
        }
        return "Stash \(formattedMoney(abs(snapshot.roomDelta)))"
    }
}

private struct CushionLoadingCard: View {
    let theme: BabloResolvedTheme

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return HStack(spacing: 12) {
            ProgressView()
                .tint(theme.colors.textPrimary.color)
            Text("Finding what moved the cushion")
                .font(theme.typography.body(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }
}

private struct CushionCumulativePoint: Identifiable, Equatable {
    let id: String
    let label: String
    let current: Double
    let previous: Double

    static func build(from dailyEnergy: [DailyEnergyItem], period: PulsePeriod) -> [CushionCumulativePoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo

        let current = period.currentWindow
        guard
            let currentStart = fmt.date(from: current.startDate),
            let currentEnd = fmt.date(from: current.endDate),
            let previous = period.comparisonWindow,
            let previousStart = fmt.date(from: previous.startDate),
            let previousEnd = fmt.date(from: previous.endDate)
        else { return [] }

        let currentItems = dailyEnergy
            .filter { item in
                guard let date = fmt.date(from: item.dateLabel) else { return false }
                return date >= currentStart && date <= currentEnd
            }
            .sorted { $0.dateLabel < $1.dateLabel }

        let previousItems = dailyEnergy
            .filter { item in
                guard let date = fmt.date(from: item.dateLabel) else { return false }
                return date >= previousStart && date <= previousEnd
            }
            .sorted { $0.dateLabel < $1.dateLabel }

        guard !currentItems.isEmpty, !previousItems.isEmpty else { return [] }

        if period == .month {
            let cal = Calendar.bablo
            func weekIndex(for date: Date, relativeTo start: Date) -> Int {
                let diff = cal.dateComponents([.day], from: start, to: date).day ?? 0
                return (diff / 7) + 1
            }

            var currentByWeek: [Int: Double] = [:]
            for item in currentItems {
                if let d = fmt.date(from: item.dateLabel) {
                    let w = weekIndex(for: d, relativeTo: currentStart)
                    currentByWeek[w, default: 0] += item.totalSpent
                }
            }

            var previousByWeek: [Int: Double] = [:]
            for item in previousItems {
                if let d = fmt.date(from: item.dateLabel) {
                    let w = weekIndex(for: d, relativeTo: previousStart)
                    previousByWeek[w, default: 0] += item.totalSpent
                }
            }

            let maxWeek = max(currentByWeek.keys.max() ?? 1, previousByWeek.keys.max() ?? 1)
            var currentSum = 0.0
            var previousSum = 0.0

            return (1...maxWeek).map { w in
                currentSum += currentByWeek[w, default: 0]
                previousSum += previousByWeek[w, default: 0]
                return CushionCumulativePoint(
                    id: "W\(w)",
                    label: "W\(w)",
                    current: currentSum,
                    previous: previousSum
                )
            }
        } else if period == .day {
            return [
                CushionCumulativePoint(
                    id: "today",
                    label: "Day",
                    current: currentItems.reduce(0) { $0 + $1.totalSpent },
                    previous: previousItems.reduce(0) { $0 + $1.totalSpent }
                )
            ]
        } else {
            let labels = ["M", "T", "W", "T", "F", "S", "S"]
            var currentSum = 0.0
            var previousSum = 0.0

            return currentItems.enumerated().map { index, item in
                currentSum += item.totalSpent
                if index < previousItems.count {
                    previousSum += previousItems[index].totalSpent
                }
                return CushionCumulativePoint(
                    id: item.dateLabel,
                    label: index < labels.count ? labels[index] : String(item.weekday.prefix(1)),
                    current: currentSum,
                    previous: previousSum
                )
            }
        }
    }
}

private func formattedMoney(_ amount: Double) -> String {
    let rounded = Int(amount.rounded())
    if rounded < 0 {
        return "-$\(abs(rounded).formatted())"
    }
    return "$\(rounded.formatted())"
}

private func formattedSigned(_ amount: Double) -> String {
    let sign = amount >= 0 ? "+" : "-"
    return "\(sign)\(formattedMoney(abs(amount)))"
}

// MARK: - PulsePeriod + Swing labels

private extension PulsePeriod {
    var swingPeriodLabel: String {
        switch self {
        case .day:   return "Day over day"
        case .week:  return "Week over week"
        case .month: return "Month over month"
        }
    }

    var previousPeriodLabel: String {
        switch self {
        case .day:   return "YESTERDAY"
        case .week:  return "LAST WK"
        case .month: return "LAST MO"
        }
    }

    var currentPeriodLabel: String {
        switch self {
        case .day:   return "TODAY"
        case .week:  return "THIS WK"
        case .month: return "THIS MO"
        }
    }

    var previousPeriodShortLabel: String {
        switch self {
        case .day:   return "yesterday"
        case .week:  return "last wk"
        case .month: return "last mo"
        }
    }

    var currentPeriodShortLabel: String {
        switch self {
        case .day:   return "today"
        case .week:  return "this wk"
        case .month: return "this mo"
        }
    }

    var currentWindowLabel: String {
        displayLabel(for: currentWindow)
    }

    var previousWindowLabel: String {
        guard let comparisonWindow else { return "" }
        return displayLabel(for: comparisonWindow)
    }

    var cushionSubtitle: String {
        switch self {
        case .day:
            return "\(currentWindowLabel) vs yesterday"
        case .week:
            return "\(currentWindowLabel) vs the week before"
        case .month:
            return "\(currentWindowLabel) vs last month"
        }
    }

    func swingSubtitle(report: PulseDamageReport) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo

        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = .bablo

        switch self {
        case .day:
            guard let start = fmt.date(from: report.startDate) else { return "Today vs yesterday" }
            display.dateFormat = "MMM d"
            return "\(display.string(from: start)) vs yesterday"

        case .week:
            guard
                let start = fmt.date(from: report.startDate),
                let end   = fmt.date(from: report.endDate)
            else { return "This week vs last" }
            display.dateFormat = "MMM d"
            return "\(display.string(from: start)) – \(display.string(from: end)) vs the week before"

        case .month:
            guard let start = fmt.date(from: report.startDate) else { return "This month vs last" }
            display.dateFormat = "MMMM"
            let prev = Calendar.bablo.date(byAdding: .month, value: -1, to: start)
            let prevName = prev.map { display.string(from: $0) } ?? "last month"
            return "\(display.string(from: start)) vs \(prevName)"
        }
    }

    func currentDateRangeLabel(report: PulseDamageReport) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo
        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = .bablo
        display.dateFormat = "MMM d"

        switch self {
        case .day:
            return fmt.date(from: report.startDate).map { display.string(from: $0) } ?? ""
        case .week:
            guard let s = fmt.date(from: report.startDate), let e = fmt.date(from: report.endDate) else { return "" }
            return "\(display.string(from: s)) – \(display.string(from: e))"
        case .month:
            guard let s = fmt.date(from: report.startDate) else { return "" }
            display.dateFormat = "MMMM"
            return display.string(from: s)
        }
    }

    func previousDateRangeLabel(report: PulseDamageReport) -> String {
        guard let win = comparisonWindow else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo
        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = .bablo
        display.dateFormat = "MMM d"

        switch self {
        case .day:
            return fmt.date(from: win.startDate).map { display.string(from: $0) } ?? ""
        case .week:
            guard let s = fmt.date(from: win.startDate), let e = fmt.date(from: win.endDate) else { return "" }
            return "\(display.string(from: s)) – \(display.string(from: e))"
        case .month:
            guard let s = fmt.date(from: win.startDate) else { return "" }
            display.dateFormat = "MMMM"
            return display.string(from: s)
        }
    }

    private func displayLabel(for window: PulseDateWindow) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = .bablo
        fmt.timeZone = .bablo

        let display = DateFormatter()
        display.calendar = .bablo
        display.timeZone = .bablo
        display.dateFormat = "MMM d"

        guard let start = fmt.date(from: window.startDate) else { return "" }

        switch self {
        case .day:
            return display.string(from: start)
        case .week:
            guard let end = fmt.date(from: window.endDate) else { return display.string(from: start) }
            return "\(display.string(from: start)) - \(display.string(from: end))"
        case .month:
            display.dateFormat = "MMMM"
            return display.string(from: start)
        }
    }
}

// MARK: - Week By Week Swing Card

private struct SwingWeekBar: Identifiable {
    let id = UUID()
    let label: String
    let weekStart: String
    let weekEnd: String
    let title: String
    let currentAmount: Double
    let previousAmount: Double
    let isPeak: Bool
    let peakLabel: String?
    let spentMore: Bool
}

private struct WeekByWeekSwingCard: View {
    let bars: [SwingWeekBar]
    let theme: BabloResolvedTheme
    var onWeekTapped: ((String, String, String, Double) -> Void)? = nil

    private var maxAmount: Double {
        bars.flatMap { [$0.currentAmount, $0.previousAmount] }.max() ?? 1
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isPopArt ? "WEEK BY WEEK" : "Week by week")
                    .font(theme.typography.title(size: 16, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Spacer()

                Text("ghost = last period")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }

            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(bars) { bar in
                        SwingWeekBarColumn(
                            bar: bar,
                            maxAmount: max(maxAmount, 1),
                            theme: theme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onWeekTapped?(bar.weekStart, bar.weekEnd, bar.title, bar.currentAmount)
                        }
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
        .shadow(color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04), radius: isPopArt ? 0 : 12, x: isPopArt ? theme.effects.shadowX : 0, y: isPopArt ? theme.effects.shadowY : 4)
    }
}

private struct SwingWeekBarColumn: View {
    let bar: SwingWeekBar
    let maxAmount: Double
    let theme: BabloResolvedTheme

    private let maxBarHeight: CGFloat = 84

    private func barHeight(amount: Double) -> CGFloat {
        guard amount > 0 else { return 0 }
        return max(CGFloat(amount / maxAmount) * maxBarHeight, 4)
    }

    private var currentBarColor: Color {
        bar.spentMore ? theme.colors.danger.color : theme.colors.success.color
    }

    private var truncatedPeakLabel: String? {
        guard let label = bar.peakLabel else { return nil }
        if label.count > 12 {
            return String(label.prefix(10)) + "..."
        }
        return label
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if bar.isPeak, let label = truncatedPeakLabel {
                Text(label)
                    .font(theme.typography.body(size: 10, weight: .bold))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .fixedSize()
                    .padding(.bottom, 4)
            }

            HStack(alignment: .bottom, spacing: 2) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if bar.currentAmount > 0 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(currentBarColor)
                            .frame(height: barHeight(amount: bar.currentAmount))
                    }
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if bar.previousAmount > 0 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(height: barHeight(amount: bar.previousAmount))
                            .overlay {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(theme.colors.line.color, lineWidth: 0.5)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension Date {
    func monthName(calendar: Calendar) -> String {
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone
        fmt.dateFormat = "MMM"
        return fmt.string(from: self)
    }

    func dayNumber(calendar: Calendar) -> String {
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone
        fmt.dateFormat = "d"
        return fmt.string(from: self)
    }
}

// MARK: - Calendar helpers

private extension TimeZone {
    static var bablo: TimeZone { Calendar.bablo.timeZone }
}

// MARK: - Previews

#if DEBUG

#Preview("The Swing · Week · Plain") {
    let service = PulsePreviewSwingFixtures.dataService()
    return TheSwingSheetView(
        report: service.damageReport!,
        breakdown: service.categoryBreakdown ?? [],
        dailyEnergy: PulsePreviewSwingFixtures.weekDailyEnergy,
        period: .week,
        dismissAction: {}
    )
    .babloTheme(.normal)
}

#Preview("The Swing · Week · Pop") {
    let service = PulsePreviewSwingFixtures.dataService()
    return TheSwingSheetView(
        report: service.damageReport!,
        breakdown: service.categoryBreakdown ?? [],
        dailyEnergy: PulsePreviewSwingFixtures.weekDailyEnergy,
        period: .week,
        dismissAction: {}
    )
    .babloTheme(.pop)
}

#Preview("The Swing · Month · Plain") {
    let service = PulsePreviewSwingFixtures.monthService()
    return TheSwingSheetView(
        report: service.damageReport!,
        breakdown: service.categoryBreakdown ?? [],
        dailyEnergy: [],
        period: .month,
        dismissAction: {}
    )
    .babloTheme(.normal)
}

@MainActor
private enum PulsePreviewSwingFixtures {
    static func dataService() -> PulseService {
        let service = PulseService()
        service.damageReport = PulseDamageReport(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            totalIn: 612,
            totalOut: 387,
            spentDeltaFromPrevious: 76,
            comparisonLabel: "vs last wk"
        )
        service.categoryBreakdown = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 142, transactionCount: 11, percentOfTotal: 0.37, previousAmount: 103),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 48, transactionCount: 3, percentOfTotal: 0.12, previousAmount: 22),
            CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 68, transactionCount: 7, percentOfTotal: 0.18, previousAmount: 74),
            CategoryBreakdownItem(bucket: .category(.fun), totalAmount: 55, transactionCount: 4, percentOfTotal: 0.14, previousAmount: 49),
            CategoryBreakdownItem(bucket: .category(.groceries), totalAmount: 42, transactionCount: 5, percentOfTotal: 0.11, previousAmount: 44),
            CategoryBreakdownItem(bucket: .category(.coffeeRuns), totalAmount: 32, transactionCount: 6, percentOfTotal: 0.08, previousAmount: 32),
        ]
        return service
    }

    static func monthService() -> PulseService {
        let service = PulseService()
        service.damageReport = PulseDamageReport(
            startDate: "2026-05-01",
            endDate: "2026-05-31",
            totalIn: 5200,
            totalOut: 3100,
            spentDeltaFromPrevious: -420,
            comparisonLabel: "vs last mo"
        )
        service.categoryBreakdown = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 620, transactionCount: 28, percentOfTotal: 0.20, previousAmount: 780),
            CategoryBreakdownItem(bucket: .category(.groceries), totalAmount: 480, transactionCount: 12, percentOfTotal: 0.15, previousAmount: 440),
            CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 310, transactionCount: 22, percentOfTotal: 0.10, previousAmount: 360),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 290, transactionCount: 8, percentOfTotal: 0.09, previousAmount: 190),
            CategoryBreakdownItem(bucket: .category(.fun), totalAmount: 240, transactionCount: 10, percentOfTotal: 0.08, previousAmount: 260),
        ]
        return service
    }

    static let weekDailyEnergy: [DailyEnergyItem] = [
        // Previous week (May 6–12)
        DailyEnergyItem(weekday: "Mon", dateLabel: "2026-05-06", totalSpent: 45, isPeak: false, peakMerchant: "Starbucks", peakCategory: nil, peakAmount: 12),
        DailyEnergyItem(weekday: "Tue", dateLabel: "2026-05-07", totalSpent: 38, isPeak: false, peakMerchant: "Trader Joes", peakCategory: nil, peakAmount: 38),
        DailyEnergyItem(weekday: "Wed", dateLabel: "2026-05-08", totalSpent: 62, isPeak: false, peakMerchant: "Sweetgreen", peakCategory: nil, peakAmount: 18),
        DailyEnergyItem(weekday: "Thu", dateLabel: "2026-05-09", totalSpent: 71, isPeak: false, peakMerchant: "Amazon", peakCategory: nil, peakAmount: 55),
        DailyEnergyItem(weekday: "Fri", dateLabel: "2026-05-10", totalSpent: 55, isPeak: false, peakMerchant: "Lyft", peakCategory: nil, peakAmount: 24),
        DailyEnergyItem(weekday: "Sat", dateLabel: "2026-05-11", totalSpent: 28, isPeak: false, peakMerchant: "Netflix", peakCategory: nil, peakAmount: 16),
        DailyEnergyItem(weekday: "Sun", dateLabel: "2026-05-12", totalSpent: 12, isPeak: false, peakMerchant: "Apple", peakCategory: nil, peakAmount: 12),
        // Current week (May 13–19)
        DailyEnergyItem(weekday: "Mon", dateLabel: "2026-05-13", totalSpent: 32, isPeak: false, peakMerchant: "Starbucks", peakCategory: nil, peakAmount: 18),
        DailyEnergyItem(weekday: "Tue", dateLabel: "2026-05-14", totalSpent: 64, isPeak: false, peakMerchant: "Whole Foods", peakCategory: nil, peakAmount: 42),
        DailyEnergyItem(weekday: "Wed", dateLabel: "2026-05-15", totalSpent: 18, isPeak: false, peakMerchant: "Uber", peakCategory: nil, peakAmount: 18),
        DailyEnergyItem(weekday: "Thu", dateLabel: "2026-05-16", totalSpent: 88, isPeak: false, peakMerchant: "Amazon", peakCategory: nil, peakAmount: 55),
        DailyEnergyItem(weekday: "Fri", dateLabel: "2026-05-17", totalSpent: 124, isPeak: true, peakMerchant: "Concert", peakCategory: nil, peakAmount: 124),
        DailyEnergyItem(weekday: "Sat", dateLabel: "2026-05-18", totalSpent: 41, isPeak: false, peakMerchant: "Grocery", peakCategory: nil, peakAmount: 41),
        DailyEnergyItem(weekday: "Sun", dateLabel: "2026-05-19", totalSpent: 20, isPeak: false, peakMerchant: "Netflix", peakCategory: nil, peakAmount: 20),
    ]
}

#endif
