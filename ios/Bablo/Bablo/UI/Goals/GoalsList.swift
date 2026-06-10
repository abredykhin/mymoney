//
//  GoalsList.swift
//  Bablo
//
//  Scrollable list section of all goal rows plus the "All goals" header.
//

import SwiftUI

struct GoalsList: View {
    let goals: [GoalSummaryItem]
    let onGoalTap: (GoalSummaryItem) -> Void

    @EnvironmentObject private var goalsService: GoalsService
    @EnvironmentObject private var accountsService: AccountsService
    @State private var selectedGoal: GoalSummaryItem?
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All goals")
                        .font(theme.typography.title(size: 18, weight: theme.effects.isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Text("\(goals.count) active · tap to open")
                        .font(theme.typography.body(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
                Spacer()
            }

            if goals.isEmpty {
                Text("No goals yet. Tap + to add one.")
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        GoalRowView(goal: goal)
                            .onTapGesture {
                                selectedGoal = goal
                            }
                            .accessibilityIdentifier("goals.row.\(goal.id)")

                        if index < goals.count - 1 {
                            Rectangle()
                                .fill(theme.colors.line.color)
                                .frame(height: theme.effects.isPopArt
                                    ? theme.metrics.strongBorderWidth
                                    : theme.metrics.borderWidth)
                        }
                    }
                }
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                        .stroke(
                            theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                            lineWidth: theme.effects.isPopArt
                                ? theme.metrics.strongBorderWidth
                                : theme.metrics.borderWidth
                        )
                }
                .shadow(
                    color: theme.effects.isPopArt
                        ? theme.effects.shadowColor
                        : theme.effects.shadowColor.opacity(0.04),
                    radius: theme.effects.isPopArt ? 0 : theme.effects.shadowRadius,
                    x: theme.effects.shadowX,
                    y: theme.effects.shadowY
                )
            }
        }
        .sheet(item: $selectedGoal, onDismiss: {
            Task { try? await goalsService.fetchGoalsSummary() }
        }) { goal in
            GoalDetailSheet(goal: goal)
                .environmentObject(goalsService)
                .environmentObject(accountsService)
        }
    }
}

#Preview("Goals List · Normal") {
    GoalsList(goals: GoalsPreviewFixtures.goals, onGoalTap: { _ in })
        .padding()
        .environmentObject(GoalsService())
        .environmentObject(AccountsService())
        .babloTheme(.normal)
}

#Preview("Goals List · Pop") {
    GoalsList(goals: GoalsPreviewFixtures.goals, onGoalTap: { _ in })
        .padding()
        .environmentObject(GoalsService())
        .environmentObject(AccountsService())
        .babloTheme(.pop)
}
