//
//  GoalRowView.swift
//  Bablo
//
//  Single goal row matching the mockup: icon, name, amount, progress bar,
//  ETA / status label, weekly rate. Funded goals show a green badge + confetti emoji.
//

import SwiftUI

struct GoalRowView: View {
    let goal: GoalSummaryItem

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 10) {
            // Row 1: icon + name + amount / funded badge
            HStack(alignment: .center, spacing: 12) {
                // Emoji icon badge
                ZStack {
                    if isPopArt {
                        Rectangle()
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Rectangle()
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 40, height: 40)
                    }
                    Text(goal.categoryIcon)
                        .font(.system(size: 20))
                }

                // Name
                Text(goal.name)
                    .font(theme.typography.body(size: 15, weight: isPopArt ? .black : .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                Spacer()

                // Amount or funded badge
                if goal.isFunded {
                    fundedBadge
                } else {
                    amountLabel
                }
            }

            // Row 2: progress bar (colored per goal)
            BabloProgressBar(
                progress: goal.progressPercent,
                height: isPopArt ? 10 : 7,
                tintColor: Color(hex: goal.color) ?? theme.colors.accent.color
            )

            // Row 3: ETA / status  ·  pct + weekly rate
            HStack {
                // Left: ETA + status
                if goal.isFunded {
                    Text("Smashed it 🎉")
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.success.color)
                } else {
                    Text(etaStatusText)
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                // Right: pct · weekly rate
                HStack(spacing: 4) {
                    Text("\(Int(goal.pct))%")
                        .font(theme.typography.mono(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)

                    if goal.weeklyRate > 0 && !goal.isFunded {
                        Text("·")
                            .foregroundStyle(theme.colors.textTertiary.color)
                        Text("+\(formatCurrency(goal.weeklyRate))/wk")
                            .font(theme.typography.mono(size: 12, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Sub-views

    private var fundedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("FUNDED")
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1)
        }
        .foregroundStyle(theme.colors.surface.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.colors.success.color)
        .clipShape(Capsule())
        .overlay {
            if theme.effects.isPopArt {
                Capsule().stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
            }
        }
    }

    private var amountLabel: some View {
        HStack(spacing: 3) {
            Text(formatCurrency(goal.currentAmount))
                .font(theme.typography.mono(size: 14, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
            Text("/")
                .font(theme.typography.body(size: 13))
                .foregroundStyle(theme.colors.textTertiary.color)
            Text(formatCurrency(goal.targetAmount))
                .font(theme.typography.body(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary.color)
        }
    }

    // MARK: - Computed

    private var etaStatusText: String {
        let statusPart: String
        switch goal.statusLabel {
        case "on track": statusPart = "on track"
        case "almost":   statusPart = "almost"
        case "building": statusPart = "building"
        case "at risk":  statusPart = "at risk"
        default:         statusPart = goal.statusLabel
        }

        if let etaString = goal.etaDate {
            let formatted = formattedEta(etaString)
            return "ETA \(formatted) · \(statusPart)"
        } else {
            return statusPart.capitalized
        }
    }

    private var statusColor: Color {
        switch goal.statusLabel {
        case "on track": return theme.colors.info.color
        case "almost":   return theme.colors.warning.color
        case "at risk":  return theme.colors.danger.color
        default:         return theme.colors.textTertiary.color
        }
    }

    private func formattedEta(_ dateString: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        if let date = isoFmt.date(from: dateString) {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM yyyy"
            return fmt.string(from: date)
        }
        return dateString
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

// MARK: - Previews

#Preview("Goal Row · On Track · Normal") {
    VStack(spacing: 0) {
        GoalRowView(goal: GoalsPreviewFixtures.goals[0])
        Divider()
        GoalRowView(goal: GoalsPreviewFixtures.goals[1])
        Divider()
        GoalRowView(goal: GoalsPreviewFixtures.goals[2])
        Divider()
        GoalRowView(goal: GoalsPreviewFixtures.goals[3])
    }
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .padding()
    .babloTheme(.normal)
}

#Preview("Goal Row · Pop") {
    VStack(spacing: 0) {
        GoalRowView(goal: GoalsPreviewFixtures.goals[0])
        Rectangle().fill(Color.black).frame(height: 2)
        GoalRowView(goal: GoalsPreviewFixtures.goals[3])
    }
    .background(Color.white)
    .padding()
    .babloTheme(.pop)
}
