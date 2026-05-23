import Foundation

/// The eight flexible spending categories shown in onboarding Step 5.
/// Raw value is stored in `profiles_table.tracked_spending_categories`.
enum FlexibleSpendingCategory: String, CaseIterable, Identifiable {
    case eatsOut      = "eats_out"
    case coffeeRuns   = "coffee_runs"
    case groceries    = "groceries"
    case fun          = "fun"
    case shopping     = "shopping"
    case gettingAround = "getting_around"
    case selfCare     = "self_care"
    case travel       = "travel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eatsOut:       return "Eats out"
        case .coffeeRuns:    return "Coffee runs"
        case .groceries:     return "Groceries"
        case .fun:           return "Fun"
        case .shopping:      return "Shopping"
        case .gettingAround: return "Getting around"
        case .selfCare:      return "Self-care"
        case .travel:        return "Travel"
        }
    }

    var subtitle: String {
        switch self {
        case .eatsOut:       return "restaurants, takeout"
        case .coffeeRuns:    return "café visits"
        case .groceries:     return "food at home"
        case .fun:           return "games, events, drinks"
        case .shopping:      return "clothes, gear"
        case .gettingAround: return "Uber, transit, gas"
        case .selfCare:      return "hair, nails, skin"
        case .travel:        return "trips, weekend escapes"
        }
    }

    var emoji: String {
        switch self {
        case .eatsOut:       return "🍜"
        case .coffeeRuns:    return "☕"
        case .groceries:     return "🥑"
        case .fun:           return "🎮"
        case .shopping:      return "🛍️"
        case .gettingAround: return "🚗"
        case .selfCare:      return "💅"
        case .travel:        return "✈️"
        }
    }
}
