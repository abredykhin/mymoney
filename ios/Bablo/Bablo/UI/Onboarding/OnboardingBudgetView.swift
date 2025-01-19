//
//  OnboardingBudgetView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/18/24.
//

import SwiftUI

struct OnboardingBudgetView: View {
    @State private var incomePeriod: BudgetPeriod = .monthly
    @State private var displayPeriod: BudgetPeriod = .monthly
    @State private var income: Double = 4000
    @State private var targetSavings: Double = 1000
    @State private var necessaryExpenses: Double = 2000
    @State private var isUsingCategories: Bool = false
    @State private var discretionarySpending: Double = 800
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingBudgetHeaderView()
                
                IncomeInputView(
                    income: $income,
                    period: $incomePeriod
                )
                
                ExpenseSection(
                    title: "Need to spend",
                    amount: $necessaryExpenses,
                    period: $displayPeriod,
                    description: "Regular bills and essential expenses"
                )
                
                ExpenseSection(
                    title: "Want to save",
                    amount: $targetSavings,
                    period: $displayPeriod,
                    description: "Your savings goal"
                )
                
                DiscretionarySpendingView(
                    isUsingCategories: $isUsingCategories,
                    amount: $discretionarySpending,
                    period: displayPeriod
                )
                
                OnboardingBudgetFooterView()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}


#Preview {
    OnboardingBudgetView()
}
