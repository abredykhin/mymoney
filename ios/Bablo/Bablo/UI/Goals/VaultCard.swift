//
//  VaultCard.swift
//  Bablo
//
//  The hero "Vault" card shown at the top of the Goals tab.
//  Shows total stashed, funded %, a liquid fill animation, and vault coverage.
//

import SwiftUI

struct VaultCard: View {
    let summary: GoalsSummary

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let progress = summary.totalTarget > 0
            ? min(1.0, summary.totalStashed / summary.totalTarget)
            : 0.0

        VStack(spacing: 0) {
            // Top section: liquid vessel + info
            HStack(alignment: .center, spacing: 20) {
                // Animated liquid vessel
                LiquidVesselView(progress: progress)
                    .frame(width: 88, height: 120)

                // Text details
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE VAULT")
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.colors.textTertiary.color)

                    Text(formatCurrency(summary.totalStashed))
                        .font(theme.typography.display(size: 36, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("of \(formatCurrency(summary.totalTarget)) target")
                        .font(theme.typography.body(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)

                    HStack(spacing: 8) {
                        // Funded % badge
                        Text("\(Int(summary.fundedPct))% funded")
                            .font(theme.typography.body(size: 12, weight: isPopArt ? .black : .bold))
                            .foregroundStyle(theme.colors.accentInk.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.colors.accent.color)
                            .clipShape(Capsule())
                            .overlay {
                                if isPopArt {
                                    Capsule().stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                                }
                            }
                    }

                    // Vault coverage indicator
                    vaultCoverageIndicator
                }

                Spacer(minLength: 0)
            }
            .padding(theme.metrics.cardPadding)

            // Divider
            Rectangle()
                .fill(theme.colors.line.color)
                .frame(height: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)

            // Stats row
            HStack(spacing: 0) {
                StatCell(label: "Stashed", value: formatCurrency(summary.totalStashed))
                statDivider
                StatCell(label: "This month", value: summary.thisMonth >= 0
                    ? "+\(formatCurrency(summary.thisMonth))"
                    : formatCurrency(summary.thisMonth))
                statDivider
                StatCell(label: "Goals", value: "\(summary.goalCount)")
            }
            .frame(height: 64)
        }
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
            color: isPopArt ? theme.effects.shadowColor : theme.effects.shadowColor.opacity(0.05),
            radius: isPopArt ? 0 : theme.effects.shadowRadius,
            x: theme.effects.shadowX,
            y: theme.effects.shadowY
        )
        .accessibilityIdentifier("goals.vaultCard")
    }

    @ViewBuilder
    private var vaultCoverageIndicator: some View {
        if !summary.vaultCovered {
            let overage = summary.totalStashed - summary.depositoryBalance
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Vault \(formatCurrency(overage)) over real balance")
                    .font(theme.typography.body(size: 10, weight: .semibold))
            }
            .foregroundStyle(theme.colors.warning.color)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color)
            .frame(width: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)
            .frame(maxHeight: .infinity)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let label: String
    let value: String

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(theme.typography.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.colors.textTertiary.color)

            Text(value)
                .font(theme.typography.body(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Liquid Vessel

/// Animated liquid-fill pill/capsule matching the mockup's vessel graphic.
struct LiquidVesselView: View {
    let progress: Double  // 0.0 – 1.0

    @State private var waveOffset: CGFloat = 0
    @Environment(\.babloTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let fillY = h * (1.0 - progress)
            let isPopArt = theme.effects.isPopArt

            ZStack {
                // Vessel outline background
                if isPopArt {
                    Rectangle()
                        .fill(theme.colors.surfaceMuted.color)
                        .overlay {
                            Rectangle().stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                } else {
                    Capsule()
                        .fill(theme.colors.surfaceMuted.color)
                }

                // Liquid fill clipped to vessel shape
                Canvas { ctx, size in
                    let path = wavePath(in: size, yOffset: fillY)
                    ctx.fill(path, with: .color(theme.colors.accent.color))
                }
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: waveOffset)
                .clipShape(isPopArt ? AnyShape(Rectangle()) : AnyShape(Capsule()))

                // Percentage label centred
                Text("\(Int(progress * 100))%")
                    .font(theme.typography.body(size: 13, weight: .black))
                    .foregroundStyle(progress > 0.35
                        ? theme.colors.accentInk.color
                        : theme.colors.textPrimary.color)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                waveOffset = 1.0
            }
        }
    }

    private func wavePath(in size: CGSize, yOffset: CGFloat) -> Path {
        let w = size.width
        let h = size.height
        var path = Path()
        let amplitude: CGFloat = 6
        let phase = waveOffset * w * 2

        path.move(to: CGPoint(x: 0, y: yOffset))

        var x: CGFloat = 0
        while x <= w {
            let y = yOffset + amplitude * sin((x + phase) / w * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

private struct AnyShape: Shape {
    nonisolated(unsafe) private let pathFn: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathFn = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        pathFn(rect)
    }
}

// MARK: - Previews

#Preview("Vault Card · Normal · Covered") {
    VaultCard(summary: GoalsSummary(
        totalStashed: 5060,
        totalTarget: 9900,
        fundedPct: 51.1,
        goalCount: 4,
        thisMonth: 420,
        depositoryBalance: 7500,
        vaultCovered: true,
        goals: []
    ))
    .padding()
    .babloTheme(.normal)
}

#Preview("Vault Card · Normal · Not Covered") {
    VaultCard(summary: GoalsSummary(
        totalStashed: 5060,
        totalTarget: 9900,
        fundedPct: 51.1,
        goalCount: 4,
        thisMonth: 420,
        depositoryBalance: 3200,
        vaultCovered: false,
        goals: []
    ))
    .padding()
    .babloTheme(.normal)
}

#Preview("Vault Card · Pop") {
    VaultCard(summary: GoalsSummary(
        totalStashed: 5060,
        totalTarget: 9900,
        fundedPct: 51.1,
        goalCount: 4,
        thisMonth: 420,
        depositoryBalance: 7500,
        vaultCovered: true,
        goals: []
    ))
    .padding()
    .babloTheme(.pop)
}
