//
//  PeriodPickerView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

// Period Picker Component
struct PeriodPickerView: View {
    @Binding var period: BudgetPeriod
    
    var body: some View {
        Menu {
            Picker("Period", selection: $period) {
                ForEach(BudgetPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
        } label: {
            HStack {
                Text("per \(period.shortName)")
                    .font(Typography.body)
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.backgroundSecondary)
            .cornerRadius(CornerRadius.sm)
        }
    }
}
