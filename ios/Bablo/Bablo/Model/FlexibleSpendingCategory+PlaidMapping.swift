import Foundation

extension FlexibleSpendingCategory {
    /// Maps Plaid's `personal_finance_category` (primary) and optional
    /// `personal_finance_subcategory` (detailed) to a `FlexibleSpendingCategory`.
    ///
    /// Subcategory takes priority when it contains a distinguishing keyword (e.g. coffee, grocery).
    /// Returns `nil` for categories that don't represent discretionary user spending
    /// (income, transfers, loan payments, rent, utilities, bank fees, etc.).
    static func map(primary: String?, detailed: String?) -> FlexibleSpendingCategory? {
        let sub = (detailed ?? "").uppercased()
        let pri = (primary ?? "").uppercased()

        // Subcategory has priority for items that share a primary with others
        if sub.contains("COFFEE")  { return .coffeeRuns }
        if sub.contains("GROCER")  { return .groceries }

        // Route by primary category
        if pri.hasPrefix("FOOD_AND_DRINK")       { return .eatsOut }
        if pri.hasPrefix("ENTERTAINMENT")        { return .fun }
        if pri.hasPrefix("GENERAL_MERCHANDISE")  { return .shopping }
        if pri.hasPrefix("HOME_IMPROVEMENT")     { return .shopping }
        if pri.hasPrefix("TRANSPORTATION")       { return .gettingAround }
        if pri.hasPrefix("PERSONAL_CARE")        { return .selfCare }
        if pri.hasPrefix("MEDICAL")              { return .selfCare }
        if pri.hasPrefix("TRAVEL")               { return .travel }

        // Income, transfers, loan payments, rent/utilities, bank fees, government → untracked
        return nil
    }
}
