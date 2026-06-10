//
//  GoalsPreviewFixtures.swift
//  Bablo
//
//  Mock data used for SwiftUI Previews in Goals UI components.
//

import Foundation

struct GoalsPreviewFixtures {
    static let goals: [GoalSummaryItem] = [
        GoalSummaryItem(
            id: 1,
            name: "Japan trip",
            categoryIcon: "✈️",
            targetAmount: 5000.0,
            currentAmount: 1720.0,
            etaDate: "2026-08-01",
            isActive: true,
            color: "#4A9EFF",
            priority: 0,
            pct: 34.4,
            weeklyRate: 84.0,
            thisMonth: 340.0,
            statusLabel: "on track",
            fundingMode: "auto_stash",
            monthlyContribution: 340.0
        ),
        GoalSummaryItem(
            id: 2,
            name: "Tesla Fund",
            categoryIcon: "🚗",
            targetAmount: 80000.0,
            currentAmount: 20000.0,
            etaDate: nil,
            isActive: true,
            color: "#FF453A",
            priority: 1,
            pct: 25.0,
            weeklyRate: 0.0,
            thisMonth: 0.0,
            statusLabel: "at risk",
            fundingMode: "auto_stash",
            monthlyContribution: 0.0
        ),
        GoalSummaryItem(
            id: 3,
            name: "Emergency Fund",
            categoryIcon: "🏦",
            targetAmount: 10000.0,
            currentAmount: 9500.0,
            etaDate: "2026-06-15",
            isActive: true,
            color: "#30D158",
            priority: 2,
            pct: 95.0,
            weeklyRate: 150.0,
            thisMonth: 600.0,
            statusLabel: "almost",
            fundingMode: "auto_stash",
            monthlyContribution: 600.0
        ),
        GoalSummaryItem(
            id: 4,
            name: "Festival Pass",
            categoryIcon: "🎟️",
            targetAmount: 500.0,
            currentAmount: 500.0,
            etaDate: nil,
            isActive: true,
            color: "#BF5AF2",
            priority: 3,
            pct: 100.0,
            weeklyRate: 0.0,
            thisMonth: 0.0,
            statusLabel: "funded",
            fundingMode: "auto_stash",
            monthlyContribution: 0.0
        )
    ]

    static let summary = GoalsSummary(
        totalStashed: 31720.0,
        totalTarget: 95500.0,
        fundedPct: 33.2,
        goalCount: 4,
        thisMonth: 940.0,
        depositoryBalance: 45000.0,
        vaultCovered: true,
        goals: goals
    )

    static let summaryUncovered = GoalsSummary(
        totalStashed: 31720.0,
        totalTarget: 95500.0,
        fundedPct: 33.2,
        goalCount: 4,
        thisMonth: 940.0,
        depositoryBalance: 25000.0,
        vaultCovered: false,
        goals: goals
    )
}
