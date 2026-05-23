import Testing
@testable import Bablo

struct FixedExpenseCategoryTests {

    // Every category must have a non-empty display name
    @Test func allCategoriesHaveDisplayName() {
        for category in FixedExpenseCategory.allCases {
            #expect(!category.displayName.isEmpty, "displayName empty for \(category)")
        }
    }

    // Every category must have a non-empty emoji
    @Test func allCategoriesHaveEmoji() {
        for category in FixedExpenseCategory.allCases {
            #expect(!category.emoji.isEmpty, "emoji empty for \(category)")
        }
    }

    // Every category must have a non-empty subtitle
    @Test func allCategoriesHaveSubtitle() {
        for category in FixedExpenseCategory.allCases {
            #expect(!category.subtitle.isEmpty, "subtitle empty for \(category)")
        }
    }

    // Every category must have a positive suggested default amount
    @Test func allCategoriesHavePositiveDefault() {
        for category in FixedExpenseCategory.allCases {
            #expect(category.suggestedDefault > 0, "suggestedDefault <= 0 for \(category)")
        }
    }

    // There are exactly 7 categories matching the design
    @Test func exactlySevenCategories() {
        #expect(FixedExpenseCategory.allCases.count == 7)
    }

    // Raw values must be stable strings (used as recurring stream match_pattern)
    @Test func rawValuesAreStable() {
        #expect(FixedExpenseCategory.rent.rawValue == "rent_mortgage")
        #expect(FixedExpenseCategory.phone.rawValue == "phone_bill")
        #expect(FixedExpenseCategory.utilities.rawValue == "utilities")
        #expect(FixedExpenseCategory.streaming.rawValue == "streaming_apps")
        #expect(FixedExpenseCategory.gym.rawValue == "gym")
        #expect(FixedExpenseCategory.loan.rawValue == "loan_debt")
        #expect(FixedExpenseCategory.insurance.rawValue == "insurance")
    }

    // Verify specific display names match the design copy exactly
    @Test func specificDisplayNames() {
        #expect(FixedExpenseCategory.rent.displayName == "Rent / mortgage")
        #expect(FixedExpenseCategory.phone.displayName == "Phone bill")
        #expect(FixedExpenseCategory.streaming.displayName == "Streaming + apps")
    }
}
