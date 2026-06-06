import SwiftUI

// MARK: - The Cushion Sheet

struct TheCushionSheetView: View {
    let snapshot: HeroCushionSnapshot
    let period: PulsePeriod
    let breakdown: [CategoryBreakdownItem]
    let dailySeries: CushionDailySeries?
    let isLoading: Bool
    let dismissAction: () -> Void
    let primaryAction: () -> Void

    @Environment(\.babloTheme) private var theme

    private var drivers: [HeroCushionDriver] {
        HeroCushionDriver.drivers(from: breakdown, scale: snapshot.roomScale)
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

                SheetCloseButton(theme: theme, showsBorder: true, action: dismissAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            Divider()
                .overlay(theme.colors.line.color)
        }
        .background(theme.colors.surface.color)
    }

    private var cumulativePoints: [CushionCumulativePoint] {
        // Built from the same discretionary series the hero/drivers use (variable_transactions,
        // aligned windows), so no rescaling hack is needed — the endpoint already equals the
        // hero's spend totals.
        guard let dailySeries else { return [] }
        return CushionCumulativePoint.build(series: dailySeries, period: period)
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
        // amount/current/previous are cushion ("left to spend") values and may be negative when
        // over budget. Scale bars by magnitude so the larger cushion fills the bar; clamp at 0.
        let maxVal = max(abs(current), abs(previous))
        guard maxVal > 0 else { return 0.0 }
        return max(0.0, amount / maxVal)
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

            // Bars show the CUSHION (safe-to-spend left), not raw spend, so the headline delta
            // is literally the difference between the two bars — no mental math required.
            VStack(spacing: 10) {
                roomRow(
                    title: period.previousPeriodLabel + " LEFT",
                    dateRange: period.previousWindowLabel,
                    amount: snapshot.previousRoom,
                    isCurrent: false
                )

                roomRow(
                    title: period.currentPeriodLabel + " LEFT",
                    dateRange: period.currentWindowLabel,
                    amount: snapshot.currentRoom,
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
        let rawFill = calculateFillFraction(amount: amount, current: snapshot.currentRoom, previous: snapshot.previousRoom)
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
                    if driver.barSide == .left {
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
                    if driver.barSide == .right {
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
        return "\(formattedMoney(driver.previousAmount)) → \(formattedMoney(driver.currentAmount))"
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
        let horizon = paceHorizon(for: snapshot.period)
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0 ? "\(amount) better \(horizon)" : "\(amount) deeper \(horizon)"
        }
        return "\(amount) \(snapshot.hasMoreRoom ? "under" : "over") \(horizon)"
    }

    /// The end-of-period the pace projects toward, matched to the selected period.
    private static func paceHorizon(for period: HeroPeriod) -> String {
        switch period {
        case .day:   return "by day's end"
        case .week:  return "by week's end"
        case .month: return "by month-end"
        }
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

    /// Build the cumulative pace line from the discretionary daily series. Both windows are
    /// gap-filled (a day with no spend counts as $0) and aligned by elapsed position, so the
    /// current and previous lines compare like-for-like.
    static func build(series: CushionDailySeries, period: PulsePeriod) -> [CushionCumulativePoint] {
        let currentDays = filledDays(points: series.current, start: series.currentStart, end: series.currentEnd)
        let previousDays = filledDays(points: series.previous, start: series.previousStart, end: series.previousEnd)
        guard !currentDays.isEmpty || !previousDays.isEmpty else { return [] }

        switch period {
        case .day:
            return [
                CushionCumulativePoint(
                    id: "today",
                    label: "Day",
                    current: currentDays.reduce(0) { $0 + $1.amount },
                    previous: previousDays.reduce(0) { $0 + $1.amount }
                )
            ]

        case .month:
            // Daily cumulative, aligned by elapsed position (current = month-to-date, previous =
            // the MTD-aligned prior-month window). Weekly buckets used to collapse to a single
            // point early in the month (days 1–6 → one week → just two dots, no line); a per-day
            // line always renders and reads like-for-like. Labels are sparse day-of-month numbers
            // so a full month doesn't crowd the axis.
            let count = max(currentDays.count, previousDays.count)
            guard count > 0 else { return [] }
            let labelStride = max(1, Int((Double(count) / 6.0).rounded(.up)))
            var currentSum = 0.0
            var previousSum = 0.0
            return (0..<count).map { i in
                if i < currentDays.count { currentSum += currentDays[i].amount }
                if i < previousDays.count { previousSum += previousDays[i].amount }
                let id = i < currentDays.count ? currentDays[i].date : "d\(i)"
                let showLabel = (i % labelStride == 0) || i == count - 1
                var label = ""
                if showLabel, i < currentDays.count {
                    let dayStr = currentDays[i].date.split(separator: "-").last.map(String.init) ?? ""
                    label = Int(dayStr).map(String.init) ?? dayStr
                }
                return CushionCumulativePoint(id: id, label: label, current: currentSum, previous: previousSum)
            }

        case .week:
            let cal = Calendar.bablo
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.calendar = cal
            fmt.timeZone = cal.timeZone
            let letters = ["S", "M", "T", "W", "T", "F", "S"]
            let count = max(currentDays.count, previousDays.count)
            var currentSum = 0.0
            var previousSum = 0.0
            return (0..<count).map { i in
                if i < currentDays.count { currentSum += currentDays[i].amount }
                if i < previousDays.count { previousSum += previousDays[i].amount }
                let label: String
                if i < currentDays.count, let d = fmt.date(from: currentDays[i].date) {
                    label = letters[(cal.component(.weekday, from: d) - 1) % 7]
                } else {
                    label = ""
                }
                let id = i < currentDays.count ? currentDays[i].date : "d\(i)"
                return CushionCumulativePoint(id: id, label: label, current: currentSum, previous: previousSum)
            }
        }
    }

    /// Expand a sparse spend series into one entry per calendar day in [start, end], $0 for gaps.
    private static func filledDays(points: [CushionDailyPoint], start: String, end: String) -> [CushionDailyPoint] {
        let cal = Calendar.bablo
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        guard let startDate = fmt.date(from: start), let endDate = fmt.date(from: end), startDate <= endDate else {
            return points.sorted { $0.date < $1.date }
        }
        let byDate = Dictionary(points.map { ($0.date, $0.amount) }, uniquingKeysWith: +)
        var out: [CushionDailyPoint] = []
        var d = startDate
        while d <= endDate {
            let label = fmt.string(from: d)
            out.append(CushionDailyPoint(date: label, amount: byDate[label] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
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

#if DEBUG

#Preview("The Cushion · Week") {
    TheCushionSheetView(
        snapshot: CushionPreviewFixtures.weekSnapshot,
        period: .week,
        breakdown: CushionPreviewFixtures.weekBreakdown,
        dailySeries: CushionPreviewFixtures.weekDailySeries,
        isLoading: false,
        dismissAction: {},
        primaryAction: {}
    )
    .babloTheme(.normal)
}

#Preview("The Cushion · Month") {
    TheCushionSheetView(
        snapshot: CushionPreviewFixtures.monthSnapshot,
        period: .month,
        breakdown: CushionPreviewFixtures.monthBreakdown,
        dailySeries: CushionPreviewFixtures.monthDailySeries,
        isLoading: false,
        dismissAction: {},
        primaryAction: {}
    )
    .babloTheme(.pop)
}

private enum CushionPreviewFixtures {
    static let weekSnapshot = HeroCushionSnapshot(
        calculator: HeroBudgetCalculator(
            monthlyIncome: 5_400,
            monthlyMandatoryExpenses: 2_250,
            knownIncomeThisMonth: 5_400,
            extraIncomeThisMonth: 0,
            variableSpend: 860,
            currentWeekVariableSpend: 188,
            todayVariableSpend: 42,
            liquidCashAvailable: nil,
            spendingPlanMode: .monthlyPlan,
            upcomingUnpaidExpenses: 0,
            previousDayVariableSpend: 58,
            previousWeekVariableSpend: 310,
            previousMonthVariableSpend: 1_420,
            dayOfMonth: 12,
            daysInMonth: 30,
            daysElapsedInWeek: 4
        ),
        period: .week
    )!

    static let monthSnapshot = HeroCushionSnapshot(
        calculator: HeroBudgetCalculator(
            monthlyIncome: 5_400,
            monthlyMandatoryExpenses: 2_250,
            knownIncomeThisMonth: 5_400,
            extraIncomeThisMonth: 120,
            variableSpend: 1_040,
            currentWeekVariableSpend: 210,
            todayVariableSpend: 36,
            liquidCashAvailable: nil,
            spendingPlanMode: .monthlyPlan,
            upcomingUnpaidExpenses: 0,
            previousDayVariableSpend: 52,
            previousWeekVariableSpend: 240,
            previousMonthVariableSpend: 1_390,
            dayOfMonth: 12,
            daysInMonth: 30,
            daysElapsedInWeek: 4
        ),
        period: .month
    )!

    static let weekBreakdown: [CategoryBreakdownItem] = [
        CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 76, transactionCount: 5, percentOfTotal: 0.40, previousAmount: 138),
        CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 18, transactionCount: 1, percentOfTotal: 0.10, previousAmount: 82),
        CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 44, transactionCount: 6, percentOfTotal: 0.23, previousAmount: 39),
        CategoryBreakdownItem(bucket: .category(.groceries), totalAmount: 60, transactionCount: 2, percentOfTotal: 0.32, previousAmount: 71),
        CategoryBreakdownItem(bucket: .category(.coffeeRuns), totalAmount: 10, transactionCount: 2, percentOfTotal: 0.05, previousAmount: 24),
    ]

    static let monthBreakdown: [CategoryBreakdownItem] = [
        CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 310, transactionCount: 18, percentOfTotal: 0.30, previousAmount: 520),
        CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 120, transactionCount: 4, percentOfTotal: 0.12, previousAmount: 260),
        CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 180, transactionCount: 14, percentOfTotal: 0.17, previousAmount: 150),
        CategoryBreakdownItem(bucket: .category(.groceries), totalAmount: 260, transactionCount: 8, percentOfTotal: 0.25, previousAmount: 300),
        CategoryBreakdownItem(bucket: .category(.fun), totalAmount: 170, transactionCount: 6, percentOfTotal: 0.16, previousAmount: 160),
    ]

    static var weekDailySeries: CushionDailySeries {
        dailySeries(
            period: .week,
            current: [28, 34, 42, 18, 24, 22, 16],
            previous: [44, 52, 64, 38, 48, 36, 30]
        )
    }

    static var monthDailySeries: CushionDailySeries {
        dailySeries(
            period: .month,
            current: [42, 18, 26, 38, 0, 52, 31, 47, 24, 36, 20, 28],
            previous: [72, 44, 36, 58, 90, 66, 32, 54, 70, 38, 62, 48]
        )
    }

    private static func dailySeries(period: PulsePeriod, current: [Double], previous: [Double]) -> CushionDailySeries {
        let currentWindow = period.currentWindow
        let previousWindow = period.comparisonWindow ?? currentWindow
        return CushionDailySeries(
            current: points(start: currentWindow.startDate, amounts: current),
            previous: points(start: previousWindow.startDate, amounts: previous),
            currentStart: currentWindow.startDate,
            currentEnd: currentWindow.endDate,
            previousStart: previousWindow.startDate,
            previousEnd: previousWindow.endDate
        )
    }

    private static func points(start: String, amounts: [Double]) -> [CushionDailyPoint] {
        let cal = Calendar.bablo
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone

        guard let startDate = fmt.date(from: start) else { return [] }
        return amounts.enumerated().compactMap { offset, amount in
            guard let date = cal.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return CushionDailyPoint(date: fmt.string(from: date), amount: amount)
        }
    }
}

#endif
