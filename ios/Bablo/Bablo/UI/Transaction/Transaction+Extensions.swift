//
//  Transaction+Extensions.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import Foundation

extension Transaction {
    // Function to get icon name based on primary category
    func getCategoryIconName() -> String {
        // Check for primary category
        guard let primaryCategory = self.personal_finance_category else {
            return "creditcard" // Default icon if no primary category
        }
        
        // Map primary categories to SF Symbols
        switch primaryCategory.uppercased() {
        case "INCOME":
            return "dollarsign.circle"
        case "TRANSFER_IN":
            return "arrow.down.circle"
        case "TRANSFER_OUT":
            return "arrow.up.circle"
        case "LOAN_PAYMENTS":
            return "banknote"
        case "BANK_FEES":
            return "building.columns"
        case "ENTERTAINMENT":
            return "tv"
        case "FOOD_AND_DRINK":
            return "fork.knife"
        case "GENERAL_MERCHANDISE":
            return "cart"
        case "HOME_IMPROVEMENT":
            return "house"
        case "MEDICAL":
            return "cross.case"
        case "PERSONAL_CARE":
            return "heart"
        case "GENERAL_SERVICES":
            return "briefcase"
        case "GOVERNMENT_AND_NON_PROFIT":
            return "building.columns.circle"
        case "TRANSPORTATION":
            return "car"
        case "TRAVEL":
            return "airplane"
        case "RENT_AND_UTILITIES":
            return "bolt.horizontal.circle"
        default:
            return "creditcard" // Default icon for unknown primary categories
        }
    }
    
    // For more specific icon mapping based on detailed subcategory
    func getDetailedCategoryIconName() -> String {
        // If no subcategory exists, fall back to primary category
        guard let subcategory = self.personal_finance_subcategory, !subcategory.isEmpty else {
            return getCategoryIconName()
        }
        
        // Map specific subcategories to more precise icons
        switch subcategory.uppercased() {
        // INCOME subcategories
        case "INCOME_DIVIDENDS":
            return "chart.line.uptrend.xyaxis.circle"
        case "INCOME_INTEREST_EARNED":
            return "percent"
        case "INCOME_RETIREMENT_PENSION":
            return "takeoutbag.and.cup.and.straw"
            
        // FOOD subcategories
        case "FOOD_AND_DRINK_RESTAURANT":
            return "fork.knife"
        case "FOOD_AND_DRINK_COFFEE":
            return "cup.and.saucer"
        case "FOOD_AND_DRINK_FAST_FOOD":
            return "hamburger"
        case "FOOD_AND_DRINK_GROCERIES":
            return "basket"
            
        // TRANSPORTATION subcategories
        case "TRANSPORTATION_GAS":
            return "fuelpump"
        case "TRANSPORTATION_PARKING":
            return "p.circle"
        case "TRANSPORTATION_PUBLIC_TRANSIT":
            return "bus"
            
        // TRAVEL subcategories
        case "TRAVEL_FLIGHTS":
            return "airplane.departure"
        case "TRAVEL_LODGING":
            return "bed.double"
        case "TRAVEL_RENTAL_CARS":
            return "car.circle"
            
        // Add more mappings as needed...
            
        default:
            // If subcategory not recognized, fall back to primary category
            return getCategoryIconName()
        }
    }
}
