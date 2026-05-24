import Testing
import Foundation
@testable import Bablo

struct PlaidCategoryMapperTests {

    // MARK: - Coffee

    @Test func coffeeSubcategoryMapsToCoffeeRuns() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_COFFEE") == .coffeeRuns)
    }

    @Test func coffeeShopSubcategoryMapsToCoffeeRuns() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_COFFEE_SHOP") == .coffeeRuns)
    }

    // MARK: - Groceries

    @Test func groceriesSubcategoryMapsToGroceries() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES") == .groceries)
    }

    // MARK: - Eats Out

    @Test func restaurantSubcategoryMapsToEatsOut() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT") == .eatsOut)
    }

    @Test func fastFoodSubcategoryMapsToEatsOut() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_FAST_FOOD") == .eatsOut)
    }

    @Test func foodPrimaryAloneDefaultsToEatsOut() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: nil) == .eatsOut)
    }

    @Test func beerWineSubcategoryMapsToEatsOut() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_BEER_WINE_AND_LIQUOR") == .eatsOut)
    }

    // MARK: - Fun

    @Test func entertainmentPrimaryMapsToFun() {
        #expect(FlexibleSpendingCategory.map(primary: "ENTERTAINMENT", detailed: nil) == .fun)
    }

    @Test func entertainmentTvSubcategoryMapsToFun() {
        #expect(FlexibleSpendingCategory.map(primary: "ENTERTAINMENT", detailed: "ENTERTAINMENT_TV_AND_MOVIES") == .fun)
    }

    @Test func entertainmentVideoGamesSubcategoryMapsToFun() {
        #expect(FlexibleSpendingCategory.map(primary: "ENTERTAINMENT", detailed: "ENTERTAINMENT_VIDEO_GAMES") == .fun)
    }

    // MARK: - Shopping

    @Test func generalMerchandisePrimaryMapsToShopping() {
        #expect(FlexibleSpendingCategory.map(primary: "GENERAL_MERCHANDISE", detailed: nil) == .shopping)
    }

    @Test func generalMerchandiseClothingMapsToShopping() {
        #expect(FlexibleSpendingCategory.map(primary: "GENERAL_MERCHANDISE", detailed: "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES") == .shopping)
    }

    @Test func homeImprovementPrimaryMapsToShopping() {
        #expect(FlexibleSpendingCategory.map(primary: "HOME_IMPROVEMENT", detailed: nil) == .shopping)
    }

    // MARK: - Getting Around

    @Test func transportationPrimaryMapsToGettingAround() {
        #expect(FlexibleSpendingCategory.map(primary: "TRANSPORTATION", detailed: nil) == .gettingAround)
    }

    @Test func rideShareSubcategoryMapsToGettingAround() {
        #expect(FlexibleSpendingCategory.map(primary: "TRANSPORTATION", detailed: "TRANSPORTATION_TAXIS_AND_RIDE_SHARES") == .gettingAround)
    }

    @Test func gasSubcategoryMapsToGettingAround() {
        #expect(FlexibleSpendingCategory.map(primary: "TRANSPORTATION", detailed: "TRANSPORTATION_GAS") == .gettingAround)
    }

    // MARK: - Self-Care

    @Test func personalCarePrimaryMapsToSelfCare() {
        #expect(FlexibleSpendingCategory.map(primary: "PERSONAL_CARE", detailed: nil) == .selfCare)
    }

    @Test func medicalPrimaryMapsToSelfCare() {
        #expect(FlexibleSpendingCategory.map(primary: "MEDICAL", detailed: nil) == .selfCare)
    }

    @Test func hairBeautySubcategoryMapsToSelfCare() {
        #expect(FlexibleSpendingCategory.map(primary: "PERSONAL_CARE", detailed: "PERSONAL_CARE_HAIR_AND_BEAUTY") == .selfCare)
    }

    // MARK: - Travel

    @Test func travelPrimaryMapsToTravel() {
        #expect(FlexibleSpendingCategory.map(primary: "TRAVEL", detailed: nil) == .travel)
    }

    @Test func flightSubcategoryMapsToTravel() {
        #expect(FlexibleSpendingCategory.map(primary: "TRAVEL", detailed: "TRAVEL_FLIGHTS") == .travel)
    }

    @Test func lodgingSubcategoryMapsToTravel() {
        #expect(FlexibleSpendingCategory.map(primary: "TRAVEL", detailed: "TRAVEL_LODGING") == .travel)
    }

    // MARK: - Unmapped (nil)

    @Test func incomeReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "INCOME", detailed: nil) == nil)
    }

    @Test func transferInReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "TRANSFER_IN", detailed: nil) == nil)
    }

    @Test func transferOutReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "TRANSFER_OUT", detailed: nil) == nil)
    }

    @Test func loanPaymentsReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "LOAN_PAYMENTS", detailed: nil) == nil)
    }

    @Test func bankFeesReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "BANK_FEES", detailed: nil) == nil)
    }

    @Test func rentAndUtilitiesReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "RENT_AND_UTILITIES", detailed: nil) == nil)
    }

    @Test func generalServicesReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "GENERAL_SERVICES", detailed: nil) == nil)
    }

    @Test func nilPrimaryReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: nil, detailed: nil) == nil)
    }

    @Test func emptyPrimaryReturnsNil() {
        #expect(FlexibleSpendingCategory.map(primary: "", detailed: nil) == nil)
    }

    // MARK: - Case insensitivity

    @Test func lowercasePrimaryMapsCorrectly() {
        #expect(FlexibleSpendingCategory.map(primary: "food_and_drink", detailed: nil) == .eatsOut)
    }

    @Test func lowercaseCoffeeSubcategoryMapsToCoffeeRuns() {
        #expect(FlexibleSpendingCategory.map(primary: "food_and_drink", detailed: "food_and_drink_coffee") == .coffeeRuns)
    }

    // MARK: - Subcategory priority over primary

    @Test func coffeeSubcategoryTakesPriorityOverFoodPrimary() {
        // Primary says food_and_drink but subcategory is coffee → coffeeRuns wins
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_COFFEE_SHOP") == .coffeeRuns)
    }

    @Test func grocerySubcategoryTakesPriorityOverFoodPrimary() {
        #expect(FlexibleSpendingCategory.map(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES") == .groceries)
    }
}
