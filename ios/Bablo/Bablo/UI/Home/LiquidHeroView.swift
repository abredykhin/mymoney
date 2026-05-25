import SwiftUI
import UIKit

// MARK: - Period

enum HeroPeriod: String, CaseIterable {
    case day   = "Day"
    case week  = "Wk"
    case month = "Mo"

    var topBarLabel: String {
        switch self {
        case .day:   return topBarDateLabel(for: .day)
        case .week:  return topBarDateLabel(for: .week)
        case .month: return topBarDateLabel(for: .month)
        }
    }
}

// MARK: - LiquidHeroView

struct LiquidHeroView: View {
    @EnvironmentObject private var budgetService: BudgetService
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme

    @Binding var period: HeroPeriod
    @State private var animatedFill: Double = 0

    init(period: Binding<HeroPeriod> = .constant(.month)) {
        self._period = period
    }

    // MARK: - Budget calculator (pure, testable)

    private var calculator: HeroBudgetCalculator {
        let cal = Calendar.current
        let now = Date()
        return HeroBudgetCalculator(
            monthlyIncome: budgetService.monthlyIncome,
            monthlyMandatoryExpenses: budgetService.monthlyMandatoryExpenses,
            knownIncomeThisMonth: budgetService.knownIncomeThisMonth,
            extraIncomeThisMonth: budgetService.extraIncomeThisMonth,
            variableSpend: budgetService.variableSpend,
            currentWeekVariableSpend: budgetService.currentWeekVariableSpend,
            todayVariableSpend: budgetService.todayVariableSpend,
            liquidCashAvailable: budgetService.totalBalance?.balance,
            spendingPlanMode: userAccount.spendingPlanMode,
            upcomingUnpaidExpenses: budgetService.upcomingUnpaidBills,
            previousWeekVariableSpend: budgetService.previousWeekVariableSpend,
            previousMonthVariableSpend: budgetService.previousMonthVariableSpend,
            dayOfMonth: cal.component(.day, from: now),
            daysInMonth: cal.range(of: .day, in: .month, for: now)?.count ?? 30
        )
    }

    private var effectiveBudget: Double     { calculator.effectiveBudget(for: period) }
    private var spentSoFar: Double         { calculator.spentSoFar(for: period) }
    private var spendable: Double          { calculator.spendable(for: period) }
    private var fillTarget: Double         { calculator.fillTarget(for: period) }
    private var deltaLabel: String?        { calculator.deltaLabel(for: period) }

    /// Denominator text shown in the status strip.
    /// Monthly shows income ("of $X earned"); week/day show the period budget.
    private var denominatorText: String {
        switch period {
        case .month:
            let income = calculator.effectiveIncome
            guard income > 0 else { return "of \(moneyStr(effectiveBudget))" }
            return "of \(moneyStr(income)) earned"
        case .week, .day:
            return "of \(moneyStr(effectiveBudget))"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.bottom, 12)
            liquidCanvas
            statusStrip
        }
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(
                    theme.colors.line.color,
                    lineWidth: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                )
        }
        .shadow(
            color: theme.effects.isPopArt
                ? theme.effects.shadowColor
                : theme.effects.shadowColor.opacity(0.06),
            radius: theme.effects.shadowRadius,
            x: theme.effects.shadowX,
            y: theme.effects.shadowY
        )
        .onChange(of: fillTarget) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedFill = newValue
            }
        }
        .onAppear {
            animatedFill = fillTarget
        }
    }

    // MARK: - Top row: period switch + delta chip

    private var topRow: some View {
        HStack {
            periodSwitch
            Spacer()
            deltaChip
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var periodSwitch: some View {
        BabloSegmentedControl(
            items: HeroPeriod.allCases.map { .init(id: $0, title: $0.rawValue) },
            selection: $period,
            size: .compact
        )
    }

    @ViewBuilder
    private var deltaChip: some View {
        if let label = deltaLabel {
            let isPopArt = theme.effects.isPopArt
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(
                        size: isPopArt ? 12 : 11,
                        weight: .semibold,
                        design: theme.typography.bodyDesign
                    ))
                    .tracking(isPopArt ? 0.6 : 0)
                    .textCase(isPopArt ? .uppercase : nil)
                    .lineLimit(1)
            }
            .foregroundStyle(isPopArt ? theme.colors.surface.color : theme.colors.textSecondary.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isPopArt ? theme.colors.textPrimary.color : theme.colors.surface.color.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: isPopArt ? 0 : 999))
            .overlay {
                RoundedRectangle(cornerRadius: isPopArt ? 0 : 999)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
            .shadow(color: isPopArt ? theme.effects.shadowColor : .clear, radius: 0, x: 3, y: 3)
        }
    }

    // MARK: - Liquid canvas

    private var liquidCanvas: some View {
        let isPopArt    = theme.effects.isPopArt
        let inkColor    = theme.colors.textPrimary.color
        let surfaceColor  = theme.colors.surface.color
        let surfaceMuted  = theme.colors.surfaceMuted.color
        let currentFill   = animatedFill
        let fillColors = fillGradientColors(for: currentFill)
        let (fillTop, fillBottom) = (fillColors.top, fillColors.bottom)
        let amtStr = formatAmount(spendable)
        let fontSize = amountFontSize(for: amtStr)

        return TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width
                let H = size.height
                // Prevent the wave from clipping at 100% full or 0% empty by adding a safety margin
                let waveMargin: Double = 18.0
                let y0 = waveMargin + (H - waveMargin * 2) * (1.0 - currentFill)

                // 1. Background
                let bgRect = Path(CGRect(x: 0, y: 0, width: W, height: H))
                if isPopArt {
                    ctx.fill(bgRect, with: .color(surfaceColor))
                    let cx = W / 2, cy = H / 2 - 10
                    for i in 0..<56 {
                        let a = (Double(i) / 56.0) * .pi * 2
                        let inner = 70.0 + Double(i % 7) * 3
                        let outer = 260.0 + Double(i % 5) * 8
                        var line = Path()
                        line.move(to: CGPoint(x: cx + cos(a) * inner, y: cy + sin(a) * inner))
                        line.addLine(to: CGPoint(x: cx + cos(a) * outer, y: cy + sin(a) * outer))
                        let sw: CGFloat = i % 4 == 0 ? 2.2 : 1.2
                        ctx.stroke(line, with: .color(inkColor.opacity(0.5)),
                                   style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                    }
                } else {
                    ctx.fill(bgRect, with: .linearGradient(
                        Gradient(colors: [surfaceColor, surfaceMuted]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: H)
                    ))
                }

                // 2. Compute wave path
                let wave = makePath(W: W, H: H, y0: y0, t: t, fill: currentFill)

                // 3. Liquid fill — bright at surface, slightly deeper at bottom
                if isPopArt {
                    ctx.fill(wave, with: .color(inkColor))
                } else {
                    ctx.fill(wave, with: .linearGradient(
                        Gradient(colors: [fillTop, fillBottom]),
                        startPoint: CGPoint(x: 0, y: y0),
                        endPoint: CGPoint(x: 0, y: H)
                    ))
                }

                // Pop: stroke the wave edge
                if isPopArt {
                    var edgePath = Path()
                    edgePath.move(to: CGPoint(x: 0, y: waveY(x: 0, y0: y0, t: t, fill: currentFill, W: W)))
                    var x = 4.0
                    while x <= W { edgePath.addLine(to: CGPoint(x: x, y: waveY(x: x, y0: y0, t: t, fill: currentFill, W: W))); x += 4 }
                    ctx.stroke(edgePath, with: .color(inkColor), lineWidth: 3)
                }

                // 4. Bubbles — clipped to liquid
                ctx.drawLayer { liqCtx in
                    liqCtx.clip(to: wave)
                    for b in makeBubbles(t: t, W: W, H: H) {
                        let br = CGRect(x: b.x - b.r, y: b.y - b.r, width: b.r * 2, height: b.r * 2)
                        liqCtx.fill(Path(ellipseIn: br), with: .color(.white.opacity(b.op * 0.85)))
                        if isPopArt {
                            liqCtx.stroke(Path(ellipseIn: br), with: .color(inkColor.opacity(b.op)), lineWidth: 1.2)
                        }
                    }
                }

                // 5. Amount text — dark (visible above wave)
                let textPos = CGPoint(x: W / 2, y: H / 2)
                let darkText = ctx.resolve(
                    Text(amtStr)
                        .font(.system(size: fontSize, weight: isPopArt ? .black : .bold, design: .rounded))
                        .foregroundStyle(inkColor)
                )
                ctx.draw(darkText, at: textPos, anchor: .center)

                // 6. Amount text — light (clipped to liquid, inverts inside wave)
                ctx.drawLayer { liqCtx in
                    liqCtx.clip(to: wave)
                    let lightText = ctx.resolve(
                        Text(amtStr)
                            .font(.system(size: fontSize, weight: isPopArt ? .black : .bold, design: .rounded))
                            .foregroundStyle(surfaceColor)
                    )
                    liqCtx.draw(lightText, at: textPos, anchor: .center)
                }

            }
        }
        .frame(height: 280)
    }

    // MARK: - Status strip

    private var periodLabel: String {
        switch period {
        case .day:   return "left today"
        case .week:  return "left this week"
        case .month: return "left this month"
        }
    }

    private var statusStrip: some View {
        let denominator: Double = {
            if period == .month, calculator.effectiveIncome > 0 {
                return calculator.effectiveIncome
            }
            return effectiveBudget
        }()
        let realRatio = denominator > 0 ? spendable / denominator : 0
        let pct = Int((max(0, realRatio) * 100).rounded())
        let badgeBg  = theme.effects.isPopArt ? theme.colors.accent.color : fillGradientColors(for: animatedFill).bottom
        let badgeFg: Color = theme.effects.isPopArt ? theme.colors.accentInk.color : .white
        return HStack(spacing: 6) {
            Text(moneyStr(spendable))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary.color)

            Text(denominatorText)
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.textTertiary.color)

            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.textTertiary.color)

            Text(periodLabel)
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.textTertiary.color)

            Spacer()

            Text("\(pct)%")
                .font(.system(size: 11.5, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(badgeFg)
                .background(badgeBg)
                .clipShape(RoundedRectangle(cornerRadius: 999))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.colors.surface.color.opacity(theme.effects.isPopArt ? 1 : 0.6))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.colors.line.color.opacity(theme.effects.isPopArt ? 1 : 0.5))
                .frame(height: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)
        }
    }

    // MARK: - Wave math

    private func waveY(x: Double, y0: Double, t: Double, fill: Double, W: Double) -> Double {
        let amp = 10.0 * min(1.0, fill * 5)

        // Gentle whole-container tilt
        let sloshAngle = sin(t * 0.7) * 0.02
        let slosh = (x - W / 2) * tan(sloshAngle)

        // One primary wave — a single crest/trough across the full width
        let wave1 = sin(x * (2.0 * .pi / W) + t * 1.3) * amp

        // Subtle secondary for organic texture only
        let wave2 = cos(x * (2.0 * .pi / (W * 0.5)) - t * 1.9) * amp * 0.12

        return y0 + slosh + wave1 + wave2
    }

    private func makePath(W: Double, H: Double, y0: Double, t: Double, fill: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: waveY(x: 0, y0: y0, t: t, fill: fill, W: W)))
        var x = 4.0
        while x <= W {
            path.addLine(to: CGPoint(x: x, y: waveY(x: x, y0: y0, t: t, fill: fill, W: W)))
            x += 4
        }
        path.addLine(to: CGPoint(x: W, y: H))
        path.addLine(to: CGPoint(x: 0, y: H))
        path.closeSubpath()
        return path
    }

    // MARK: - Bubble math

    private struct Bubble { let x, y, r, op: Double }

    private func makeBubbles(t: Double, W: Double, H: Double) -> [Bubble] {
        (0..<7).map { i in
            let seed: (Int) -> Double = { n in abs(sin(Double(n) * 13.37) * 10000) }
            let base  = seed(i).truncatingRemainder(dividingBy: 1)
            let x     = 30 + seed(i + 1).truncatingRemainder(dividingBy: W - 60)
            let r     = 2  + seed(i + 2).truncatingRemainder(dividingBy: 4)
            let speed = 18 + seed(i + 3).truncatingRemainder(dividingBy: 14)
            let phase = (t * speed * 0.6 + base * 1000).truncatingRemainder(dividingBy: H + 60) - 30
            return Bubble(x: x, y: H - phase, r: r, op: max(0, 0.45 - phase / H))
        }
    }

    // MARK: - Fill color (green → yellow → red as budget drains)

    // Interpolates between design-system tokens: accent (full) → danger (empty).
    // top uses the bright accent, bottom uses the deeper accentPressed shade.
    private func fillGradientColors(for fill: Double) -> (top: Color, bottom: Color) {
        let t = max(0, min(1, fill))
        return (
            top:    lerpColor(from: theme.colors.danger.color,        to: theme.colors.accent.color,        t: t),
            bottom: lerpColor(from: theme.colors.danger.color,        to: theme.colors.accentPressed.color, t: t)
        )
    }

    private func lerpColor(from: Color, to: Color, t: Double) -> Color {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0
        var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0
        UIColor(from).getRed(&fr, green: &fg, blue: &fb, alpha: nil)
        UIColor(to).getRed(&er, green: &eg, blue: &eb, alpha: nil)
        let s = CGFloat(t)
        return Color(red: fr + (er - fr) * s, green: fg + (eg - fg) * s, blue: fb + (eb - fb) * s)
    }

    // MARK: - Formatting

    private func amountFontSize(for str: String) -> CGFloat {
        let base: CGFloat = theme.effects.isPopArt ? 96 : 84
        switch str.count {
        case ..<7:  return base
        case 7..<9: return base - 16
        default:    return base - 28
        }
    }

    private func formatAmount(_ v: Double) -> String {
        let amount = Int(v.rounded())
        if amount < 0 {
            return "-$\(abs(amount).formatted())"
        }
        return "$\(amount.formatted())"
    }

    private func moneyStr(_ v: Double) -> String {
        let amount = Int(v.rounded())
        if amount < 0 {
            return "-$\(abs(amount).formatted())"
        }
        return "$\(amount.formatted())"
    }
}

// MARK: - Preview

@MainActor
private func previewServices() -> [BudgetService] {
    func make(spent: Double) -> BudgetService {
        let s = BudgetService()
        s.monthlyIncome = 3_000
        s.variableSpend = spent
        return s
    }
    return [
        make(spent: 0),      // 100% full
        make(spent: 1_560),  // 48%  mid-spend  (3000 * 0.52)
        make(spent: 9_000),  // 0%   over budget → red floor
    ]
}

private struct HeroPreviewShell: View {
    @Environment(\.babloTheme) private var theme
    let services: [BudgetService]
    private let labels = ["100%", "48%", "0%"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<services.count, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(labels[i])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .padding(.horizontal, 16)
                        LiquidHeroView()
                            .environmentObject(services[i])
                            .environmentObject(UserAccount.shared)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
    }
}

#Preview("Clean · Light") { HeroPreviewShell(services: previewServices()).babloTheme(.normal).preferredColorScheme(.light) }
#Preview("Clean · Dark")  { HeroPreviewShell(services: previewServices()).babloTheme(.normal).preferredColorScheme(.dark) }
#Preview("Pop · Light")   { HeroPreviewShell(services: previewServices()).babloTheme(.pop).preferredColorScheme(.light) }
#Preview("Pop · Dark")    { HeroPreviewShell(services: previewServices()).babloTheme(.pop).preferredColorScheme(.dark) }
