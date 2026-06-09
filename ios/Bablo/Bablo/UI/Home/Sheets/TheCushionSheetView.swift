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

            CushionVerticalScrollView(showsIndicators: false) {
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

                    if period != .day && !cumulativePoints.isEmpty {
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
                .frame(maxWidth: .infinity)
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

private struct CushionVerticalScrollView<Content: View>: UIViewControllerRepresentable {
    let showsIndicators: Bool
    @ViewBuilder let content: () -> Content

    func makeUIViewController(context _: Context) -> CushionScrollHostingController<Content> {
        CushionScrollHostingController(rootView: content(), showsIndicators: showsIndicators)
    }

    func updateUIViewController(_ controller: CushionScrollHostingController<Content>, context _: Context) {
        controller.update(rootView: content(), showsIndicators: showsIndicators)
    }
}

private final class CushionScrollHostingController<Content: View>: UIViewController {
    private let scrollView = UIScrollView()
    private let hostingController: UIHostingController<Content>

    init(rootView: Content, showsIndicators: Bool) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        scrollView.showsVerticalScrollIndicator = showsIndicators
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.refreshControl = nil
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(scrollView)
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    func update(rootView: Content, showsIndicators: Bool) {
        hostingController.rootView = rootView
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.refreshControl = nil
        scrollView.contentOffset.x = 0
    }
}

private struct CushionHeroComparisonCard: View {
    let snapshot: HeroCushionSnapshot
    let period: PulsePeriod
    let theme: BabloResolvedTheme

    private var accent: Color {
        return snapshot.hasMoreRoom ? theme.colors.success.color : theme.colors.danger.color
    }

    private var comparisonAmount: String {
        formattedMoney(abs(snapshot.roomDelta))
    }

    private var headlineTitle: String {
        let direction = snapshot.hasMoreRoom ? "MORE TO SPEND" : "LESS TO SPEND"
        return "\(direction) THAN \(period.previousPeriodLabel)"
    }

    private var comparisonSentence: AttributedString {
        let periodName: String
        let prevPeriodName: String
        switch period {
        case .month:
            periodName = "this month"
            prevPeriodName = "last month"
        case .week:
            periodName = "this week"
            prevPeriodName = "last week"
        case .day:
            periodName = "today"
            prevPeriodName = "yesterday"
        }
        let sentence = "You have \(comparisonAmount) \(snapshot.hasMoreRoom ? "more" : "less") to spend \(periodName) than \(prevPeriodName)."
        var text = AttributedString(sentence)
        if let range = text.range(of: comparisonAmount) {
            text[range].foregroundColor = accent
            text[range].font = theme.typography.body(size: 14, weight: .bold)
        }
        return text
    }

    private func calculateSpendFillFraction(amount: Double, current: Double, previous: Double) -> Double {
        let c = max(0.0, current)
        let p = max(0.0, previous)
        let maxVal = max(c, p)
        guard maxVal > 0 else { return 0.0 }
        return max(0.0, max(0.0, amount) / maxVal)
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineTitle)
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

            }

            Text(comparisonSentence)
                .font(theme.typography.body(size: 14, weight: .regular))
                .foregroundStyle(theme.colors.textSecondary.color)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                spendRow(
                    title: period.currentPeriodLabel,
                    dateRange: "",
                    amount: snapshot.currentRoom,
                    isCurrent: true
                )

                spendRow(
                    title: period.previousPeriodLabel,
                    dateRange: period.previousWindowLabel,
                    amount: snapshot.previousRoom,
                    isCurrent: false
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func spendRow(title: String, dateRange: String, amount: Double, isCurrent: Bool) -> some View {
        let rawFill = calculateSpendFillFraction(amount: amount, current: snapshot.currentRoom, previous: snapshot.previousRoom)
        let fillFraction = max(0.08, min(rawFill, 1.0))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(isCurrent ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)

                if !dateRange.isEmpty {
                    Text("· \(dateRange)")
                        .font(theme.typography.body(size: 12, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }

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
                        .fill(isCurrent ? accent : accent.opacity(0.35))
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
        drivers.map { abs($0.spendDelta) }.max() ?? 1
    }

    private var netSpendDelta: Double {
        (snapshot.currentSpend - snapshot.previousSpend).rounded()
    }

    private var netColor: Color {
        netSpendDelta <= 0 ? theme.colors.success.color : theme.colors.danger.color
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Text("HOW SPENDING IS MOVING IT")
                    .font(theme.typography.mono(size: 13, weight: isPopArt ? .black : .bold))
                    .tracking(isPopArt ? 0.7 : 0.9)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Text("vs \(period.previousPeriodShortLabel)")
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.top, 1)
                    .lineLimit(1)
            }

            VStack(spacing: 10) {
                ForEach(drivers) { driver in
                    CushionDriverRow(driver: driver, maxDelta: maxDelta, theme: theme)
                }
            }

            Divider()
                .overlay(theme.colors.line.color)

            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 4) {
                    Text("◀ saved")
                        .foregroundStyle(theme.colors.success.color)
                    Text("·")
                        .foregroundStyle(theme.colors.textTertiary.color)
                    Text("spent more ▶")
                        .foregroundStyle(theme.colors.danger.color)
                }
                .font(theme.typography.body(size: 12, weight: .bold))

                Spacer()

                Text(netSummaryText)
                    .font(theme.typography.body(size: 18, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(netColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var netSummaryText: String {
        let amount = formattedMoney(abs(netSpendDelta))
        return "\(amount) \(netSpendDelta <= 0 ? "more" : "less")"
    }
}

enum CushionSpendMovement: Equatable {
    case lowerSpend
    case higherOrEqualSpend

    init(spendDelta: Double) {
        self = spendDelta < 0 ? .lowerSpend : .higherOrEqualSpend
    }

    var systemImageName: String {
        switch self {
        case .lowerSpend:
            return "chevron.down"
        case .higherOrEqualSpend:
            return "chevron.up"
        }
    }
}

private struct CushionDriverRow: View {
    let driver: HeroCushionDriver
    let maxDelta: Double
    let theme: BabloResolvedTheme

    private var color: Color {
        driver.spendDelta <= 0 ? theme.colors.success.color : theme.colors.danger.color
    }

    private var barFraction: Double {
        min(abs(driver.spendDelta) / max(maxDelta, 1), 1.0)
    }

    private var barSide: HeroCushionDriver.BarSide {
        driver.spendDelta <= 0 ? .left : .right
    }

    private var movement: CushionSpendMovement {
        CushionSpendMovement(spendDelta: driver.spendDelta)
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
                    if barSide == .left {
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
                    if barSide == .right {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(width: max(40 * CGFloat(barFraction), 4), height: 12)
                    }
                }
                .frame(width: 40, height: 12)
            }
            .frame(width: 81, height: 18)

            HStack(spacing: 3) {
                Image(systemName: movement.systemImageName)
                    .font(.system(size: 9, weight: .black))
                Text(formattedMoney(abs(driver.spendDelta)))
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .frame(width: 74, alignment: .trailing)
        }
    }

    private var detailText: String {
        return "\(formattedMoney(driver.currentAmount))·was \(formattedMoney(driver.previousAmount))"
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

            CushionLineChart(points: points, maxValue: maxValue, period: snapshot.period, hasMoreRoom: snapshot.hasMoreRoom, theme: theme)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let period: HeroPeriod
    let hasMoreRoom: Bool
    let theme: BabloResolvedTheme

    private let yAxisLabelWidth: CGFloat = 42
    private let topInset: CGFloat = 10
    private let bottomInset: CGFloat = 34

    var body: some View {
        Canvas { ctx, size in
            let top = topInset
            let bottom = bottomInset
            let height = max(size.height - top - bottom, 1)
            let chartWidth = max(size.width - yAxisLabelWidth, 1)

            for fraction in [0.0, 0.5, 1.0] {
                var grid = Path()
                let y = top + height * CGFloat(fraction)
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: chartWidth, y: y))
                ctx.stroke(grid, with: .color(theme.colors.line.color.opacity(0.75)), lineWidth: 1)
            }

            for label in CushionChartScale.yAxisLabels(maxValue: maxValue) {
                ctx.draw(
                    Text(label.label)
                        .font(theme.typography.mono(size: 9, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color),
                    at: CGPoint(x: chartWidth + yAxisLabelWidth / 2, y: top + height * CGFloat(label.yFraction)),
                    anchor: .center
                )
            }

            for label in axisLabels {
                let x = label.xPosition(in: chartWidth)
                if period == .month {
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: top + height + 3))
                    tick.addLine(to: CGPoint(x: x, y: top + height + 8))
                    ctx.stroke(tick, with: .color(theme.colors.line.color.opacity(0.9)), lineWidth: 1)
                }

                ctx.draw(
                    Text(label.label)
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color),
                    at: CGPoint(x: x, y: top + height + 24),
                    anchor: .center
                )
            }

            let previousPath = linePath(size: size, top: top, bottom: bottom, value: \.previous)
            let currentPath = linePath(size: size, top: top, bottom: bottom, value: \.current)

            for run in fillRuns where run.points.count > 1 {
                let fillColor = run.state == .currentUnderPrevious ? theme.colors.success.color : theme.colors.danger.color
                ctx.fill(
                    areaPath(for: run.points, size: size, top: top, bottom: bottom),
                    with: .linearGradient(
                        Gradient(colors: [
                            fillColor.opacity(0.24),
                            fillColor.opacity(0.10)
                        ]),
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
                    let previous = point(for: last.previous, item: last, size: geo.size)
                    let current = point(for: last.current, item: last, size: geo.size)

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
    }

    private var axisLabels: [CushionAxisLabel] {
        switch period {
        case .month:
            guard let start = points.first?.id else { return [] }
            return CushionMonthAxis.labels(start: start, loadedDayCount: points.count)
        case .week, .day:
            return points
                .filter { !$0.label.isEmpty }
                .map { CushionAxisLabel(label: $0.label, xFraction: $0.xFraction) }
        }
    }

    private func linePath(size: CGSize, top: CGFloat, bottom: CGFloat, value: KeyPath<CushionCumulativePoint, Double>) -> Path {
        smoothPath(through: chartPoints(size: size, top: top, bottom: bottom, value: value))
    }

    private func areaPath(for runPoints: [CushionLineFillPoint], size: CGSize, top: CGFloat, bottom: CGFloat) -> Path {
        let previousPoints = runPoints.map {
            chartPoint(xFraction: $0.xFraction, amount: $0.previous, size: size, top: top, bottom: bottom)
        }
        let currentPoints = runPoints.map {
            chartPoint(xFraction: $0.xFraction, amount: $0.current, size: size, top: top, bottom: bottom)
        }
        var path = Path()
        guard let firstPrevious = previousPoints.first,
              let lastCurrent = currentPoints.last else { return path }

        path.move(to: firstPrevious)
        addSmoothSegments(to: &path, through: previousPoints)
        path.addLine(to: lastCurrent)
        addSmoothSegments(to: &path, through: Array(currentPoints.reversed()))
        path.closeSubpath()
        return path
    }

    private func chartPoints(size: CGSize, top: CGFloat, bottom: CGFloat, value: KeyPath<CushionCumulativePoint, Double>) -> [CGPoint] {
        points.map {
            chartPoint(xFraction: $0.xFraction, amount: $0[keyPath: value], size: size, top: top, bottom: bottom)
        }
    }

    private var fillRuns: [CushionLineFillRun] {
        CushionLineFillClassifier.runs(for: points.map(CushionLineFillPoint.init(point:)))
    }

    private func smoothPath(through chartPoints: [CGPoint]) -> Path {
        var path = Path()
        guard let first = chartPoints.first else { return path }
        path.move(to: first)
        addSmoothSegments(to: &path, through: chartPoints)
        return path
    }

    private func addSmoothSegments(to path: inout Path, through chartPoints: [CGPoint]) {
        guard chartPoints.count > 1 else { return }
        for index in 1..<chartPoints.count {
            let point = chartPoints[index]
            let previous = chartPoints[index - 1]
            let mid = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
            if index == chartPoints.count - 1 {
                path.addQuadCurve(to: point, control: point)
            }
        }
    }

    private func point(for amount: Double, item: CushionCumulativePoint, size: CGSize) -> CGPoint {
        chartPoint(xFraction: item.xFraction, amount: amount, size: size, top: topInset, bottom: bottomInset)
    }

    private func chartPoint(xFraction: Double, amount: Double, size: CGSize, top: CGFloat, bottom: CGFloat) -> CGPoint {
        let width = max(size.width - yAxisLabelWidth, 1)
        let height = max(size.height - top - bottom, 1)
        let x = width * CGFloat(min(max(xFraction, 0), 1))
        let y = top + height * CGFloat(1 - min(max(amount / CushionChartScale.roundedMaxValue(maxValue), 0), 1))
        return CGPoint(x: x, y: y)
    }
}

struct CushionAxisLabel: Identifiable, Equatable {
    let label: String
    let xFraction: Double

    var id: String { "\(label)-\(xFraction)" }

    func xPosition(in width: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 32
        let minX = labelWidth / 2
        let maxX = max(minX, width - labelWidth / 2)
        return min(max(width * CGFloat(min(max(xFraction, 0), 1)), minX), maxX)
    }
}

enum CushionMonthAxis {
    static func labels(start: String, loadedDayCount _: Int) -> [CushionAxisLabel] {
        let dayCount = fullMonthDayCount(start: start)
        guard dayCount > 1 else {
            return [CushionAxisLabel(label: "1", xFraction: 0)]
        }
        let middleDay = max(1, (dayCount + 1) / 2)
        let days = Array(Set([1, 7, middleDay, 21, dayCount]))
            .filter { $0 <= dayCount }
            .sorted()
        return days.map { day in
            CushionAxisLabel(
                label: "\(day)",
                xFraction: Double(day - 1) / Double(dayCount - 1)
            )
        }
    }

    private static func fullMonthDayCount(start: String) -> Int {
        let cal = Calendar.bablo
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        guard let date = fmt.date(from: start) else { return 30 }
        return cal.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}

struct CushionYAxisLabel: Identifiable, Equatable {
    let label: String
    let yFraction: Double

    var id: String { "\(label)-\(yFraction)" }
}

enum CushionChartScale {
    static func roundedMaxValue(_ maxValue: Double) -> Double {
        guard maxValue > 0 else { return 1 }
        if maxValue >= 1_000 {
            return (maxValue / 1_000).rounded(.up) * 1_000
        }
        if maxValue >= 100 {
            return (maxValue / 100).rounded(.up) * 100
        }
        if maxValue >= 10 {
            return (maxValue / 10).rounded(.up) * 10
        }
        return maxValue.rounded(.up)
    }

    static func yAxisLabels(maxValue: Double) -> [CushionYAxisLabel] {
        let topValue = roundedMaxValue(maxValue)
        return [
            CushionYAxisLabel(label: formattedAxisAmount(topValue), yFraction: 0),
            CushionYAxisLabel(label: formattedAxisAmount(topValue / 2), yFraction: 0.5),
            CushionYAxisLabel(label: "$0", yFraction: 1)
        ]
    }

    private static func formattedAxisAmount(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        guard rounded > 0 else { return "$0" }
        if rounded >= 1_000 {
            if rounded % 1_000 == 0 {
                return "$\(rounded / 1_000)k"
            }
            return "$\(String(format: "%.1f", Double(rounded) / 1_000))k"
        }
        return "$\(rounded.formatted())"
    }
}

struct CushionLineFillPoint: Equatable {
    let xFraction: Double
    let current: Double
    let previous: Double

    init(xFraction: Double, current: Double, previous: Double) {
        self.xFraction = xFraction
        self.current = current
        self.previous = previous
    }

    fileprivate init(point: CushionCumulativePoint) {
        self.xFraction = point.xFraction
        self.current = point.current
        self.previous = point.previous
    }
}

struct CushionLineFillRun: Equatable {
    enum State: Equatable {
        case currentUnderPrevious
        case currentOverPrevious
    }

    let points: [CushionLineFillPoint]
    let state: State
}

enum CushionLineFillClassifier {
    static func runs(for points: [CushionLineFillPoint]) -> [CushionLineFillRun] {
        guard let first = points.first else { return [] }

        var runs: [CushionLineFillRun] = []
        var currentRun = [first]
        var currentState = state(for: first)

        for next in points.dropFirst() {
            guard let previous = currentRun.last else { continue }
            let nextState = state(for: next)

            if nextState == currentState {
                currentRun.append(next)
            } else {
                let crossing = crossingPoint(from: previous, to: next)
                currentRun.append(crossing)
                if currentRun.count > 1 {
                    runs.append(CushionLineFillRun(points: currentRun, state: currentState))
                }
                currentRun = [crossing, next]
                currentState = nextState
            }
        }

        if currentRun.count > 1 {
            runs.append(CushionLineFillRun(points: currentRun, state: currentState))
        }
        return runs
    }

    private static func state(for point: CushionLineFillPoint) -> CushionLineFillRun.State {
        point.current <= point.previous ? .currentUnderPrevious : .currentOverPrevious
    }

    private static func crossingPoint(from start: CushionLineFillPoint, to end: CushionLineFillPoint) -> CushionLineFillPoint {
        let startDelta = start.current - start.previous
        let endDelta = end.current - end.previous
        let denominator = startDelta - endDelta
        let t = denominator == 0 ? 0.5 : min(max(startDelta / denominator, 0), 1)
        let x = lerp(start.xFraction, end.xFraction, t)
        let current = lerp(start.current, end.current, t)
        let previous = lerp(start.previous, end.previous, t)
        let crossingAmount = (current + previous) / 2
        return CushionLineFillPoint(xFraction: x, current: crossingAmount, previous: crossingAmount)
    }

    private static func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + (end - start) * t
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        return formattedMoney(abs(snapshot.roomDelta))
    }

    static func paceSummary(for snapshot: HeroCushionSnapshot) -> String {
        let amount = formattedMoney(abs(snapshot.roomDelta))
        if snapshot.currentRoom < 0 {
            return snapshot.roomDelta >= 0 ? "\(amount) better so far" : "\(amount) deeper so far"
        }
        return "\(amount) \(snapshot.hasMoreRoom ? "more" : "less") so far"
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
    let xFraction: Double

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
                    previous: previousDays.reduce(0) { $0 + $1.amount },
                    xFraction: 0
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
            let fullCount = fullMonthDayCount(start: series.currentStart)
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
                return CushionCumulativePoint(
                    id: id,
                    label: label,
                    current: currentSum,
                    previous: previousSum,
                    xFraction: xFraction(index: i, fullCount: fullCount)
                )
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
                return CushionCumulativePoint(
                    id: id,
                    label: label,
                    current: currentSum,
                    previous: previousSum,
                    xFraction: xFraction(index: i, fullCount: 7)
                )
            }
        }
    }

    private static func xFraction(index: Int, fullCount: Int) -> Double {
        guard fullCount > 1 else { return 0 }
        return min(max(Double(index) / Double(fullCount - 1), 0), 1)
    }

    private static func fullMonthDayCount(start: String) -> Int {
        let cal = Calendar.bablo
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        guard let date = fmt.date(from: start) else { return 30 }
        return cal.range(of: .day, in: .month, for: date)?.count ?? 30
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
