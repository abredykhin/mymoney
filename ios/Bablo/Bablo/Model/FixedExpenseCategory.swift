import Foundation

/// The seven preset fixed-expense categories shown in onboarding Step 4.
/// Raw value is used as `match_pattern` when creating a manual recurring stream.
enum FixedExpenseCategory: String, CaseIterable, Identifiable {
    case rent       = "rent_mortgage"
    case phone      = "phone_bill"
    case utilities  = "utilities"
    case streaming  = "streaming_apps"
    case gym        = "gym"
    case loan       = "loan_debt"
    case insurance  = "insurance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rent:       return "Rent / mortgage"
        case .phone:      return "Phone bill"
        case .utilities:  return "Utilities"
        case .streaming:  return "Streaming + apps"
        case .gym:        return "Gym"
        case .loan:       return "Loan / debt"
        case .insurance:  return "Insurance"
        }
    }

    var subtitle: String {
        switch self {
        case .rent:       return "housing"
        case .phone:      return "mobile plan"
        case .utilities:  return "electric, water, gas"
        case .streaming:  return "Netflix, Spotify, etc."
        case .gym:        return "fitness membership"
        case .loan:       return "student, auto, personal"
        case .insurance:  return "health, car, home"
        }
    }

    var emoji: String {
        switch self {
        case .rent:       return "🏠"
        case .phone:      return "📱"
        case .utilities:  return "💡"
        case .streaming:  return "📺"
        case .gym:        return "🏋️"
        case .loan:       return "🎓"
        case .insurance:  return "🛡️"
        }
    }

    /// Pre-filled default when the user taps "Add" without entering an amount.
    var suggestedDefault: Int {
        switch self {
        case .rent:       return 1200
        case .phone:      return 50
        case .utilities:  return 100
        case .streaming:  return 30
        case .gym:        return 40
        case .loan:       return 200
        case .insurance:  return 150
        }
    }
}
