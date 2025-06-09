//
//  Transaction+Extensions.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import Foundation
import SwiftUI

extension Transaction {
    
    func getCategoryDescription() -> String {
        return getTransactionCategoryDescription(
            transactionCategory: self.personal_finance_category ?? ""
        )
    }
    
    // Function to get a general icon name based on primary category
    func getCategoryIconName() -> String {
            // Check for primary category
        guard let primaryCategory = self.personal_finance_category else {
            return "creditcard" // Default icon if no primary category
        }
        
            // Map primary categories to general SF Symbols
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
            return "exclamationmark.circle"
        case "ENTERTAINMENT":
            return "popcorn" // Or "ticket", "star"
        case "FOOD_AND_DRINK":
            return "fork.knife"
        case "GENERAL_MERCHANDISE":
            return "cart"
        case "HOME_IMPROVEMENT":
            return "house"
        case "MEDICAL":
            return "cross.case"
        case "PERSONAL_CARE":
            return "figure.stand"
        case "GENERAL_SERVICES":
                // *** UPDATED: Changed from wrench.adjustable ***
            return "gearshape" // Alternative to wrench for general services
        case "GOVERNMENT_AND_NON_PROFIT":
            return "building.columns"
        case "TRANSPORTATION":
            return "car"
        case "TRAVEL":
            return "airplane"
        case "RENT_AND_UTILITIES":
            return "lightbulb"
        default:
            print("Unknown primary category: \(primaryCategory)")
            return "creditcard"
        }
    }
    
        // Function for more specific icon mapping based on detailed category
    func getDetailedCategoryIconName() -> String {
            // If no detailed category exists (or it's empty), fall back to primary category icon
        guard let detailedCategory = self.personal_finance_subcategory, !detailedCategory.isEmpty else {
            return getCategoryIconName()
        }
        
            // Map specific detailed categories to more precise icons
        switch detailedCategory.uppercased() {
            
                // === INCOME ===
        case "INCOME_DIVIDENDS":
            return "chart.line.uptrend.xyaxis"
        case "INCOME_INTEREST_EARNED":
            return "percent"
        case "INCOME_RETIREMENT_PENSION":
            return "figure.walk"
        case "INCOME_WAGES":
            return "briefcase"
        case "INCOME_TAX_REFUND":
            return "arrow.uturn.down.circle"
            
                // === TRANSFER ===
        case "TRANSFER_IN_SAVINGS", "TRANSFER_OUT_SAVINGS":
            return "piggy.bank" // Requires SF Symbols 3+
        case "TRANSFER_OUT_WITHDRAWAL":
            return "banknote"
            
                // === LOAN PAYMENTS ===
        case "LOAN_PAYMENTS_CAR_PAYMENT":
            return "car"
        case "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT":
            return "creditcard"
        case "LOAN_PAYMENTS_MORTGAGE_PAYMENT":
            return "house"
        case "LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT":
            return "graduationcap"
            
                // === BANK FEES ===
        case "BANK_FEES_OVERDRAFT_FEES":
            return "exclamationmark.triangle"
        case "BANK_FEES_INTEREST_CHARGE":
            return "percent"
            
                // === ENTERTAINMENT ===
        case "ENTERTAINMENT_MUSIC_AND_AUDIO":
            return "music.note"
        case "ENTERTAINMENT_TV_AND_MOVIES":
            return "tv"
        case "ENTERTAINMENT_VIDEO_GAMES":
            return "gamecontroller"
        case "ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS":
            return "ticket"
            
                // === FOOD & DRINK ===
        case "FOOD_AND_DRINK_RESTAURANT":
            return "fork.knife"
        case "FOOD_AND_DRINK_COFFEE":
            return "cup.and.saucer"
        case "FOOD_AND_DRINK_FAST_FOOD":
            return "takeoutbag.and.cup.and.straw" // Requires SF Symbols 4+ (iOS 16+)
        case "FOOD_AND_DRINK_GROCERIES":
            return "cart"
        case "FOOD_AND_DRINK_BEER_WINE_AND_LIQUOR":
            return "wineglass" // Requires SF Symbols 3+
            
                // === GENERAL MERCHANDISE ===
        case "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES":
            return "tshirt"
        case "GENERAL_MERCHANDISE_ELECTRONICS":
            return "desktopcomputer"
        case "GENERAL_MERCHANDISE_PET_SUPPLIES":
            return "pawprint"
        case "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES":
            return "shippingbox"
        case "GENERAL_MERCHANDISE_SUPERSTORES":
            return "building.2"
                // *** ADDED from log ***
        case "GENERAL_MERCHANDISE_BOOKSTORES_AND_NEWSSTANDS":
            return "book.closed" // or "newspaper"
            
                // === HOME IMPROVEMENT ===
        case "HOME_IMPROVEMENT_FURNITURE":
            return "chair.lounge"
        case "HOME_IMPROVEMENT_HARDWARE", "HOME_IMPROVEMENT_REPAIR_AND_MAINTENANCE":
            return "wrench.and.screwdriver" // Requires SF Symbols 2+
        case "HOME_IMPROVEMENT_SECURITY":
            return "lock.shield"
            
                // === MEDICAL ===
        case "MEDICAL_DENTAL_CARE":
            return "mouth" // Requires SF Symbols 5+ (iOS 17+)
        case "MEDICAL_EYE_CARE":
            return "eyeglasses"
        case "MEDICAL_PHARMACIES_AND_SUPPLEMENTS":
            return "pills"
        case "MEDICAL_VETERINARY_SERVICES":
            return "pawprint"
                // *** ADDED from log ***
        case "MEDICAL_OTHER_MEDICAL":
            return "waveform.path.ecg.rectangle" // Represents general medical activity
            
                // === PERSONAL CARE ===
        case "PERSONAL_CARE_GYMS_AND_FITNESS_CENTERS":
            return "dumbbell" // Requires SF Symbols 4+ or use "figure.run"
        case "PERSONAL_CARE_HAIR_AND_BEAUTY":
            return "scissors"
        case "PERSONAL_CARE_LAUNDRY_AND_DRY_CLEANING":
            return "washer" // Requires SF Symbols 4+ or use "tshirt"
            
                // === GENERAL SERVICES ===
        case "GENERAL_SERVICES_AUTOMOTIVE":
            return "car.wrench.road" // Requires SF Symbols 6+, fallback "car" or "wrench.adjustable"
        case "GENERAL_SERVICES_EDUCATION":
            return "graduationcap"
        case "GENERAL_SERVICES_INSURANCE":
            return "shield"
        case "GENERAL_SERVICES_POSTAGE_AND_SHIPPING":
            return "shippingbox"
                // *** ADDED from log ***
        case "GENERAL_SERVICES_OTHER_GENERAL_SERVICES":
            return "gearshape" // Use the primary icon for "Other"
            
                // === GOVERNMENT & NON-PROFIT ===
        case "GOVERNMENT_AND_NON_PROFIT_DONATIONS":
            return "heart"
        case "GOVERNMENT_AND_NON_PROFIT_TAX_PAYMENT":
            return "doc.text"
                // *** ADDED from log ***
        case "GOVERNMENT_AND_NON_PROFIT_GOVERNMENT_DEPARTMENTS_AND_AGENCIES":
            return "person.badge.key" // Represents official agency/ID
            
                // === TRANSPORTATION ===
        case "TRANSPORTATION_GAS":
            return "fuelpump"
        case "TRANSPORTATION_PARKING":
            return "p.circle"
        case "TRANSPORTATION_PUBLIC_TRANSIT":
            return "bus"
        case "TRANSPORTATION_TAXIS_AND_RIDE_SHARES":
            return "car.circle"
                // *** ADDED from log ***
        case "TRANSPORTATION_TOLLS":
            return "road.lanes" // Good general toll/highway symbol, widely available
                                // Alt: "tollbooth" (Requires SF Symbols 5+ / iOS 17+)
            
                // === TRAVEL ===
        case "TRAVEL_FLIGHTS":
            return "airplane.departure"
        case "TRAVEL_LODGING":
            return "bed.double"
        case "TRAVEL_RENTAL_CARS":
            return "car.circle"
            
                // === RENT & UTILITIES ===
        case "RENT_AND_UTILITIES_GAS_AND_ELECTRICITY":
            return "bolt"
        case "RENT_AND_UTILITIES_INTERNET_AND_CABLE":
            return "wifi"
        case "RENT_AND_UTILITIES_RENT":
            return "house"
        case "RENT_AND_UTILITIES_TELEPHONE":
            return "phone"
        case "RENT_AND_UTILITIES_WATER":
            return "drop"
            
                // === ADD MORE DETAILED MAPPINGS HERE ===
            
        default:
            print("Unrecognized detailed category, falling back to primary: \(detailedCategory)")
            return getCategoryIconName()
        }
    }
}

func getTransactionCategoryDescription(transactionCategory: String) -> String {
    switch transactionCategory.uppercased() {
    case "INCOME":
        return "Income"
    case "TRANSFER_IN":
        return "Incoming money transfer"
    case "TRANSFER_OUT":
        return "Outgoing money transfer"
    case "LOAN_PAYMENTS":
        return "Loan payments"
    case "BANK_FEES":
        return "Bank fees"
    case "ENTERTAINMENT":
        return "Entertainment"
    case "FOOD_AND_DRINK":
        return "Food and drink"
    case "GENERAL_MERCHANDISE":
        return "General goods"
    case "HOME_IMPROVEMENT":
        return "Home improvement"
    case "MEDICAL":
        return "Healthcare expenses"
    case "PERSONAL_CARE":
        return "Personal care"
    case "GENERAL_SERVICES":
        return "General services"
    case "GOVERNMENT_AND_NON_PROFIT":
        return "Payments to government and non-profit organizations"
    case "TRANSPORTATION":
        return "Transportation"
    case "TRAVEL":
        return "Travel"
    case "RENT_AND_UTILITIES":
        return "Rent and utility services"
    default:
        return "Unknown category"
    }
}
