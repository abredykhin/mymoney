//
//  DiscretionaryHeroView.swift
//  Bablo
//
//  Created by Antigravity on 01/23/26.
//

import SwiftUI

struct DiscretionaryHeroView: View {
    @EnvironmentObject var budgetService: BudgetService
    @State private var isWeeklyView: Bool = false
    
    // MARK: - Computed Properties

    // Total free money budget for the month (income - mandatory expenses/bills)
    // Can be negative if mandatory expenses exceed income
    private var monthlyFreeBudget: Double {
        budgetService.effectiveIncome - budgetService.monthlyMandatoryExpenses
    }

    // Variable spending this month (bills already excluded by BudgetService)
    private var monthlyVariableSpending: Double {
        budgetService.spendBreakdownResponse?.totalSpent ?? 0
    }

    // Remaining free money to spend
    private var monthlyRemaining: Double {
        monthlyFreeBudget - monthlyVariableSpending
    }

    // Weekly allocation of free budget
    private var weeklyFreeBudget: Double {
        let daysInMonth = Double(budgetService.daysRemainingInMonth + Calendar.current.component(.day, from: Date()))
        let daysInWeek = Double(budgetService.daysRemainingInCurrentWeek)

        guard daysInMonth > 0 else { return 0 }

        // Weekly allocation = (Monthly Free Budget / Days in Month) * Days in Week
        let dailyBudget = monthlyFreeBudget / Double(max(1, Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30))
        return dailyBudget * daysInWeek
    }

    // Weekly variable spending (estimated)
    private var weeklyVariableSpending: Double {
        let calendar = Calendar.current
        let currentDay = Double(calendar.component(.day, from: Date()))
        _ = Double(calendar.range(of: .day, in: .month, for: Date())?.count ?? 30)

        // Simple proportion: (monthly spending / current day) * 7
        guard currentDay > 0 else { return 0 }
        return (monthlyVariableSpending / currentDay) * 7.0
    }

    // Display amount: how much variable money has been spent
    private var displayAmount: Double {
        isWeeklyView ? weeklyVariableSpending : monthlyVariableSpending
    }

    // Total context: the free budget limit
    private var displayTotalContext: Double {
        isWeeklyView ? weeklyFreeBudget : monthlyFreeBudget
    }

    private var progress: Double {
        let budget = isWeeklyView ? weeklyFreeBudget : monthlyFreeBudget
        guard budget > 0 else { return 1 } // If no budget, we're at max
        let p = displayAmount / budget
        return max(0, min(1, p))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header Row: Title + Toggle
            HStack(alignment: .center) {
                Text("Spend Money")
                    .font(Typography.footnote)
                    .foregroundColor(ColorPalette.textSecondary)

                Spacer()

                // Toggle
                Button(action: {
                    withAnimation {
                        isWeeklyView.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isWeeklyView ? "Weekly" : "Monthly")
                            .font(.system(size: 11))
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(ColorPalette.textSecondary)
                }
            }

            // Main Amount
            Text(displayAmount, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.h3.monospaced())

            // Status Row
            HStack(spacing: Spacing.xs) {
                Image(systemName: isOverBudget ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isOverBudget ? ColorPalette.error : ColorPalette.success)

                Text(statusText)
                    .font(Typography.footnote)
                    .foregroundColor(ColorPalette.textPrimary)

                if let contextText = contextText {
                    Text(contextText)
                        .font(.system(size: 11))
                        .foregroundColor(isOverBudget ? ColorPalette.error : ColorPalette.success)
                }
            }
        }
        .glassCard()
    }

    // Helper computed properties for display text
    private var isOverBudget: Bool {
        let budget = isWeeklyView ? weeklyFreeBudget : monthlyFreeBudget
        return displayAmount > budget
    }

    private var statusText: String {
        if isOverBudget {
            return isWeeklyView ? "Over Weekly Budget" : "Over Budget"
        } else {
            return isWeeklyView ? "Spent This Week" : "Spent This Month"
        }
    }

    private var contextText: String? {
        if monthlyFreeBudget > 0 {
            return "of \(displayTotalContext.formatted(.currency(code: "USD").precision(.fractionLength(0))))"
        } else if budgetService.effectiveIncome == 0 {
            return "No income set"
        } else if monthlyFreeBudget <= 0 {
            return "Bills exceed income"
        }
        return nil
    }
}

#Preview {
    let mockService = BudgetService()
    // Setup mock data if possible or just rely on defaults
    
    return ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        DiscretionaryHeroView()
            .environmentObject(mockService)
            .padding()
    }
}
