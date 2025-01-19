//
//  BudgetPeriod.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//


enum BudgetPeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    
    var id: Self { self }    
    var shortName: String {
        switch self {
        case .weekly: return "wk"
        case .biweekly: return "2wk"
        case .monthly: return "mo"
        }
    }
    
    // Conversion factors relative to monthly
    var monthlyMultiplier: Double {
        switch self {
        case .weekly: return 1/4.33 // Average weeks in a month
        case .biweekly: return 1/2.165 // Bi-weekly to monthly
        case .monthly: return 1.0
        }
    }
}
