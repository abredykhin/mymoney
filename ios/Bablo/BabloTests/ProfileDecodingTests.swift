import Testing
import Foundation
@testable import Bablo

struct ProfileDecodingTests {

    // MARK: - Profile decoding

    @Test func profileDecodesAllFieldsIncludingTrackedCategories() throws {
        let json = """
        {
          "id": "abc-123",
          "username": "test@example.com",
          "first_name": "Mia",
          "monthly_income": 5500.00,
          "monthly_mandatory_expenses": 1282.00,
          "spending_plan_mode": "monthly_plan",
          "tracked_spending_categories": ["eats_out", "coffee_runs", "fun"]
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(Profile.self, from: json)

        #expect(profile.id == "abc-123")
        #expect(profile.username == "test@example.com")
        #expect(profile.firstName == "Mia")
        #expect(profile.monthlyIncome == 5500.0)
        #expect(profile.monthlyMandatoryExpenses == 1282.0)
        #expect(profile.spendingPlanMode == .monthlyPlan)
        #expect(profile.trackedSpendingCategories == ["eats_out", "coffee_runs", "fun"])
    }

    @Test func profileDecodesWithMissingTrackedCategoriesAsEmptyArray() throws {
        // Existing DB rows won't have this column — decoder must default to []
        let json = """
        {
          "id": "abc-123",
          "username": "test@example.com",
          "monthly_income": 0.0,
          "monthly_mandatory_expenses": 0.0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let profile = try decoder.decode(Profile.self, from: json)
        #expect(profile.firstName == nil)
        #expect(profile.spendingPlanMode == .safeToSpend)
        #expect(profile.trackedSpendingCategories == [])
    }

    @Test func profileDecodesUnknownSpendingPlanModeAsSafeToSpend() throws {
        let json = """
        {
          "id": "abc-123",
          "username": "test@example.com",
          "monthly_income": 0.0,
          "monthly_mandatory_expenses": 0.0,
          "spending_plan_mode": "future_mode"
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(Profile.self, from: json)

        #expect(profile.spendingPlanMode == .safeToSpend)
    }

    @Test func homeGreetingPrefersProfileFirstNameOverEmailFallback() {
        let user = User(id: "abc-123", name: "abredykhin+5", token: "", email: "abredykhin+5@example.com")

        let displayName = HomeGreetingResolver.displayName(profileFirstName: "Anton", user: user)

        #expect(displayName == "Anton")
    }

    @Test func homeGreetingDoesNotShowEmailUsernameFallback() {
        let user = User(id: "abc-123", name: "abredykhin+5", token: "", email: "abredykhin+5@example.com")

        let displayName = HomeGreetingResolver.displayName(profileFirstName: nil, user: user)

        #expect(displayName == "there")
    }

    @Test func profileDecodesEmptyTrackedCategoriesArray() throws {
        let json = """
        {
          "id": "xyz",
          "username": "u@u.com",
          "monthly_income": 0,
          "monthly_mandatory_expenses": 0,
          "tracked_spending_categories": []
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(Profile.self, from: json)
        #expect(profile.trackedSpendingCategories.isEmpty)
    }

    // MARK: - FlexibleSpendingCategory

    @Test func flexibleCategoryExactlyEightCases() {
        #expect(FlexibleSpendingCategory.allCases.count == 8)
    }

    @Test func flexibleCategoryRawValuesAreStable() {
        #expect(FlexibleSpendingCategory.eatsOut.rawValue     == "eats_out")
        #expect(FlexibleSpendingCategory.coffeeRuns.rawValue  == "coffee_runs")
        #expect(FlexibleSpendingCategory.groceries.rawValue   == "groceries")
        #expect(FlexibleSpendingCategory.fun.rawValue         == "fun")
        #expect(FlexibleSpendingCategory.shopping.rawValue    == "shopping")
        #expect(FlexibleSpendingCategory.gettingAround.rawValue == "getting_around")
        #expect(FlexibleSpendingCategory.selfCare.rawValue    == "self_care")
        #expect(FlexibleSpendingCategory.travel.rawValue      == "travel")
    }

    @Test func flexibleCategoryAllHaveDisplayNameEmojiAndSubtitle() {
        for cat in FlexibleSpendingCategory.allCases {
            #expect(!cat.displayName.isEmpty, "displayName empty for \(cat)")
            #expect(!cat.emoji.isEmpty,       "emoji empty for \(cat)")
            #expect(!cat.subtitle.isEmpty,    "subtitle empty for \(cat)")
        }
    }

    @Test func flexibleCategorySpecificDisplayNames() {
        #expect(FlexibleSpendingCategory.eatsOut.displayName    == "Eats out")
        #expect(FlexibleSpendingCategory.coffeeRuns.displayName == "Coffee runs")
        #expect(FlexibleSpendingCategory.gettingAround.displayName == "Getting around")
        #expect(FlexibleSpendingCategory.selfCare.displayName   == "Self-care")
    }
}
