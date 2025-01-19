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
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}
