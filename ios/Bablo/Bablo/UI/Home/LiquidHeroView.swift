import SwiftUI

// MARK: - Period

enum HeroPeriod: String, CaseIterable {
    case day   = "Day"
    case week  = "Wk"
    case month = "Mo"
}

// MARK: - LiquidHeroView

struct LiquidHeroView: View {
    @EnvironmentObject private var budgetService: BudgetService
    @Environment(\.babloTheme) private var theme

    @State private var period: HeroPeriod = .month
    @State private var animatedFill: Double = 0

    // MARK: - Budget calculator (pure, testable)

    private var calculator: HeroBudgetCalculator {
        let cal = Calendar.current
        let now = Date()
        return HeroBudgetCalculator(
            monthlyIncome: budgetService.monthlyIncome,
            monthlyMandatoryExpenses: budgetService.monthlyMandatoryExpenses,
            variableSpend: budgetService.variableSpend,
            previousWeekVariableSpend: budgetService.previousWeekVariableSpend,
            previousMonthVariableSpend: budgetService.previousMonthVariableSpend,
            dayOfMonth: cal.component(.day, from: now),
            daysInMonth: cal.range(of: .day, in: .month, for: now)?.count ?? 30
        )
    }

    private var totalDiscretionary: Double { calculator.totalDiscretionary(for: period) }
    private var spentSoFar: Double         { calculator.spentSoFar(for: period) }
    private var spendable: Double          { calculator.spendable(for: period) }
    private var fillTarget: Double         { calculator.fillTarget(for: period) }
    private var deltaLabel: String?        { calculator.deltaLabel(for: period) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topRow
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
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    private var periodSwitch: some View {
        let isPopArt = theme.effects.isPopArt
        let pillFont = Font.system(size: isPopArt ? 12 : 11.5, weight: isPopArt ? .bold : .semibold, design: theme.typography.bodyDesign)
        return HStack(spacing: 0) {
            pillButton(period: .day, font: pillFont, isPopArt: isPopArt)
            if isPopArt {
                Rectangle()
                    .fill(theme.colors.line.color)
                    .frame(width: theme.metrics.borderWidth, height: 28)
            }
            pillButton(period: .week, font: pillFont, isPopArt: isPopArt)
            if isPopArt {
                Rectangle()
                    .fill(theme.colors.line.color)
                    .frame(width: theme.metrics.borderWidth, height: 28)
            }
            pillButton(period: .month, font: pillFont, isPopArt: isPopArt)
        }
        .background(isPopArt ? theme.colors.surface.color : theme.colors.surfaceMuted.color.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: isPopArt ? 0 : 999))
        .overlay {
            RoundedRectangle(cornerRadius: isPopArt ? 0 : 999)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: isPopArt ? theme.effects.shadowColor : .clear, radius: 0, x: 3, y: 3)
    }

    private func pillButton(period p: HeroPeriod, font: Font, isPopArt: Bool) -> some View {
        let isSelected = period == p
        return Button { withAnimation(.easeOut(duration: 0.15)) { period = p } } label: {
            Text(p.rawValue)
                .font(font)
                .tracking(isPopArt ? 0.8 : 0.2)
                .textCase(isPopArt ? .uppercase : nil)
                .padding(.horizontal, isPopArt ? 13 : 11)
                .padding(.vertical, isPopArt ? 6 : 5)
                .background(isSelected ? theme.colors.textPrimary.color : Color.clear)
                .foregroundStyle(isSelected ? theme.colors.surface.color : theme.colors.textTertiary.color)
        }
        .buttonStyle(.plain)
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
        let (fillTop, fillBottom) = fillGradientColors(for: currentFill)
        let amtStr = formatAmount(spendable)
        let fontSize = amountFontSize(for: amtStr)

        return TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width
                let H = size.height
                let y0 = H * (1.0 - currentFill)

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

                // 3. Liquid fill
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
                    edgePath.move(to: CGPoint(x: 0, y: waveY(x: 0, y0: y0, t: t, fill: currentFill)))
                    var x = 4.0
                    while x <= W { edgePath.addLine(to: CGPoint(x: x, y: waveY(x: x, y0: y0, t: t, fill: currentFill))); x += 4 }
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
                let textPos = CGPoint(x: W / 2, y: H / 2 + 24)
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

                // 7. Surface highlight (default only)
                if !isPopArt {
                    var hl = Path()
                    hl.move(to: CGPoint(x: 0, y: waveY(x: 0, y0: y0, t: t, fill: currentFill)))
                    var hx = 4.0
                    while hx <= W { hl.addLine(to: CGPoint(x: hx, y: waveY(x: hx, y0: y0, t: t, fill: currentFill))); hx += 4 }
                    ctx.stroke(hl, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
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
        // Use the real ratio for the label so over-budget shows "0%", not "2%".
        let realRatio = totalDiscretionary > 0 ? spendable / totalDiscretionary : 0
        let pct = Int((max(0, realRatio) * 100).rounded())
        let badgeBg  = theme.effects.isPopArt ? theme.colors.accent.color : fillGradientColors(for: animatedFill).bottom
        let badgeFg: Color = theme.effects.isPopArt ? theme.colors.accentInk.color : .white
        return HStack(spacing: 6) {
            Text(moneyStr(spendable))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary.color)

            Text("of \(moneyStr(totalDiscretionary))")
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.colors.surface.color.opacity(theme.effects.isPopArt ? 1 : 0.6))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.colors.line.color.opacity(theme.effects.isPopArt ? 1 : 0.5))
                .frame(height: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)
        }
    }

    // MARK: - Wave math

    private func waveY(x: Double, y0: Double, t: Double, fill: Double) -> Double {
        // Amplitude scales down as the tank empties — nearly flat at 0%, full chop above ~20%.
        let base = 7 + sin(t * 0.7) * 1.4
        let amp  = base * min(1.0, fill * 5)
        return y0 + sin(x * 0.018 + t * 0.85) * amp + sin(x * 0.027 - t * 1.25) * amp * 0.45
    }

    private func makePath(W: Double, H: Double, y0: Double, t: Double, fill: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: waveY(x: 0, y0: y0, t: t, fill: fill)))
        var x = 4.0
        while x <= W {
            path.addLine(to: CGPoint(x: x, y: waveY(x: x, y0: y0, t: t, fill: fill)))
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

    private func fillGradientColors(for fill: Double) -> (top: Color, bottom: Color) {
        let hue = fill * (120.0 / 360.0)  // fill=1 → 120° green, fill=0 → 0° red
        return (
            top:    Color(hue: hue, saturation: 0.78, brightness: 0.97),
            bottom: Color(hue: hue, saturation: 0.95, brightness: 0.72)
        )
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
        "$\(Int(abs(v).rounded()).formatted())"
    }

    private func moneyStr(_ v: Double) -> String {
        "$\(Int(abs(v).rounded()).formatted())"
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
        make(spent: 9_000),  // 0%   over budget → 0.02 floor
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
