//
//  GoalsTabView.swift
//  Bablo
//
//  Root view for the Goals tab. Owns data loading and presents the
//  scrollable body plus the "Add goal" sheet.
//

import SwiftUI

struct GoalsTabView: View {
    @EnvironmentObject private var goalsService: GoalsService
    @EnvironmentObject private var accountsService: AccountsService
    @EnvironmentObject private var userAccount: UserAccount

    @State private var showAddGoal = false
    @Environment(\.babloTheme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Top bar with "+" add button
                HStack {
                    HomeTopBarView(
                        dateRangeLabel: subtitleText,
                        titleText: "Goals"
                    )

                    Spacer()

                    Button {
                        showAddGoal = true
                    } label: {
                        ZStack {
                            if theme.effects.isPopArt {
                                Rectangle()
                                    .fill(theme.colors.textPrimary.color)
                                    .frame(width: 38, height: 38)
                                    .overlay {
                                        Rectangle()
                                            .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                                    }
                                    .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                            } else {
                                Circle()
                                    .fill(theme.colors.textPrimary.color)
                                    .frame(width: 38, height: 38)
                            }
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(theme.colors.surface.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, theme.metrics.screenPadding)
                    .accessibilityLabel("Add new goal")
                    .accessibilityIdentifier("goals.addButton")
                }

                if goalsService.isSummaryLoading && goalsService.summary == nil {
                    // Initial loading skeleton
                    GoalsLoadingView()
                        .padding(.horizontal, theme.metrics.screenPadding)
                } else if let summary = goalsService.summary {
                    // Vault hero card
                    VaultCard(summary: summary)
                        .padding(.horizontal, theme.metrics.screenPadding)

                    // Goals list
                    GoalsList(goals: summary.goals, onGoalTap: { _ in })
                        .padding(.horizontal, theme.metrics.screenPadding)
                } else {
                    // Empty state
                    GoalsEmptyStateView {
                        showAddGoal = true
                    }
                    .padding(.horizontal, theme.metrics.screenPadding)
                    .padding(.top, 32)
                }
            }
            .padding(.bottom, 96)
        }
        .babloScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userAccount.currentUser?.id) {
            guard userAccount.currentUser?.id != nil else { return }
            try? await goalsService.fetchGoalsSummary()
        }
        .refreshable {
            try? await goalsService.fetchGoalsSummary()
        }
        .sheet(isPresented: $showAddGoal, onDismiss: {
            Task { try? await goalsService.fetchGoalsSummary() }
        }) {
            AddGoalSheet()
                .environmentObject(goalsService)
        }
    }

    private var subtitleText: String {
        if let summary = goalsService.summary, summary.goalCount > 0 {
            return "\(formatCurrency(summary.totalStashed)) stashed · \(summary.goalCount) goal\(summary.goalCount == 1 ? "" : "s")"
        }
        return "your savings goals"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

// MARK: - Helper Views

struct GoalsLoadingView: View {
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(theme.colors.textPrimary.color)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
}

struct GoalsEmptyStateView: View {
    let action: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("🎯")
                .font(.system(size: 64))
            
            Text("No goals yet")
                .font(theme.typography.body(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
            
            Text("Start stashing money away for your big dreams. We'll track your velocity and estimate when you'll reach them.")
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textTertiary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: action) {
                Text("Add your first goal")
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.accentInk.color)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.colors.accent.color)
                    .overlay(alignment: .center) {
                        if theme.effects.isPopArt {
                            Rectangle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                    }
                    .shadow(color: theme.effects.isPopArt ? theme.effects.shadowColor : .clear, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(theme.colors.surface.color)
        .overlay(alignment: .center) {
            if theme.effects.isPopArt {
                Rectangle()
                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
            } else {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
        }
        .shadow(color: theme.effects.isPopArt ? theme.effects.shadowColor : .clear, radius: 0, x: 4, y: 4)
    }
}

