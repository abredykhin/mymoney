import Testing
import Foundation
@testable import Bablo

struct CategoryBreakdownTests {

    // MARK: - Helpers

    /// Build a BreakdownTransaction.
    /// `isSpend` defaults to `amount > 0` — override to `false` for transactions
    /// the DB view would exclude (investment moves, credit-card payments, etc.).
    private func makeTxn(
        amount: Double,
        primary: String?,
        detailed: String? = nil,
        name: String? = nil,
        date: String? = nil,
        authorizedDate: String? = nil,
        accountType: String? = nil,
        isSpend: Bool? = nil,
        isIncome: Bool = false
    ) -> BreakdownTransaction {
        BreakdownTransaction(
            amount: amount,
            name: name,
            date: date,
            authorizedDate: authorizedDate,
            accountType: accountType,
            personal_finance_category: primary,
            personal_finance_subcategory: detailed,
            isSpend: isSpend ?? (amount > 0),
            isIncome: isIncome
        )
    }

    // MARK: - is_spend filter (mirrors DB view logic)

    @Test func transferInIsExcluded() {
        // DB sets is_spend = false for TRANSFER_IN (except ACCOUNT_TRANSFER)
        let txns = [
            makeTxn(amount: 200, primary: "TRANSFER_IN", isSpend: false),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.bucket == .category(.fun))
    }

    @Test func transferOutAccountTransferIsIncluded() {
        // Therapy payments, Venmo — DB sets is_spend = true
        let txns = [
            makeTxn(amount: 160, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_ACCOUNT_TRANSFER"),
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let eats = result.first(where: { $0.bucket == .category(.eatsOut) })
        let rest = result.first(where: { $0.bucket == .rest })
        #expect(eats?.totalAmount == 50)
        #expect(rest?.totalAmount == 160)
    }

    @Test func transferOutWithdrawalIsIncluded() {
        // ATM cash withdrawals — DB sets is_spend = true
        let txns = [
            makeTxn(amount: 303, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_WITHDRAWAL"),
            makeTxn(amount: 40, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let rest = result.first(where: { $0.bucket == .rest })
        #expect(rest?.totalAmount == 303)
    }

    @Test func transferOutInvestmentFundsExcluded() {
        // $70k brokerage / Robinhood — DB sets is_spend = false; must NOT inflate spending
        let txns = [
            makeTxn(amount: 70_000, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS", isSpend: false),
            makeTxn(amount: 14_163, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS", isSpend: false),
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.totalAmount == 50)
    }

    @Test func transferOutOtherTransferIsIncluded() {
        // Wire transfers and small purchases like Oaks Corner — DB sets is_spend = true
        let txns = [
            makeTxn(amount: 47_413, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_OTHER_TRANSFER_OUT"),
            makeTxn(amount: 9, primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_OTHER_TRANSFER_OUT"),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let rest = result.first(where: { $0.bucket == .rest })
        let fun = result.first(where: { $0.bucket == .category(.fun) })
        #expect(rest?.totalAmount == 47_422.0)
        #expect(fun?.totalAmount == 30)
    }

    @Test func wireReversalNegativeAmountIsExcluded() {
        // TRANSFER_IN_ACCOUNT_TRANSFER with negative amount — DB sets is_spend = false
        // (it contributes to is_income and total_in in the damage report RPC, not spending)
        let reversal = makeTxn(
            amount: -47_413,
            primary: "TRANSFER_IN",
            detailed: "TRANSFER_IN_ACCOUNT_TRANSFER",
            isSpend: false,
            isIncome: true
        )
        let result = CategoryBreakdownBuilder.build(currentTransactions: [reversal], trackedCategories: [])
        #expect(result.isEmpty)
    }

    @Test func brokerageInvestmentTransfersExcluded() {
        // Schwab MoneyLink and CC payment confirmations — DB sets is_spend = false
        let txns = [
            makeTxn(amount: 28_748, primary: "TRANSFER_IN", detailed: "TRANSFER_IN_INVESTMENT_AND_RETIREMENT_FUNDS", isSpend: false),
            makeTxn(amount: 343, primary: "TRANSFER_IN", detailed: "TRANSFER_IN_CASH_ADVANCES_AND_LOANS", isSpend: false),
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.totalAmount == 50)
    }

    // MARK: - Exclusion: negative amounts (income/credits)

    @Test func negativeAmountTransactionsAreExcluded() {
        let txns = [
            makeTxn(amount: -500, primary: "INCOME"),
            makeTxn(amount: 75, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.bucket == .category(.fun))
    }

    @Test func zeroAmountTransactionsAreExcluded() {
        let txns = [
            makeTxn(amount: 0, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 40, primary: "TRANSPORTATION"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.bucket == .category(.gettingAround))
    }

    // MARK: - Grouping: tracked vs untracked

    @Test func trackedCategoriesShownIndividually() {
        let txns = [
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT"),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
            makeTxn(amount: 20, primary: "TRANSPORTATION"),
        ]
        let tracked: Set<FlexibleSpendingCategory> = [.eatsOut, .fun]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: tracked)

        let buckets = result.map { $0.bucket }
        #expect(buckets.contains(.category(.eatsOut)))
        #expect(buckets.contains(.category(.fun)))
        #expect(buckets.contains(.rest))

        let rest = result.first(where: { $0.bucket == .rest })
        #expect(rest?.totalAmount == 20)
    }

    @Test func untrackedMappedCategoryGoesToRest() {
        let txns = [
            makeTxn(amount: 40, primary: "GENERAL_MERCHANDISE"),
            makeTxn(amount: 60, primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT"),
        ]
        let tracked: Set<FlexibleSpendingCategory> = [.eatsOut]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: tracked)

        #expect(result.count == 2)
        let eats = result.first(where: { $0.bucket == .category(.eatsOut) })
        let rest = result.first(where: { $0.bucket == .rest })
        #expect(eats?.totalAmount == 60)
        #expect(rest?.totalAmount == 40)
    }

    @Test func emptyTrackedCategoriesShowsAllMappedIndividuallyAndExcludesCCPayments() {
        let txns = [
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT"),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
            makeTxn(amount: 20, primary: "TRANSPORTATION"),
            // DB sets is_spend = false for CC payments
            makeTxn(amount: 15, primary: "LOAN_PAYMENTS", detailed: "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT", isSpend: false),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let buckets = Set(result.map { $0.bucket })
        #expect(buckets.contains(.category(.eatsOut)))
        #expect(buckets.contains(.category(.fun)))
        #expect(buckets.contains(.category(.gettingAround)))
        #expect(!buckets.contains(.rest))
    }

    @Test func nullCategoryPaymentNamedTransactionsAreExcluded() {
        // DB sets is_spend = false for NULL-category transactions whose name contains "Payment"
        let txns = [
            makeTxn(amount: 125, primary: nil, name: "Payment Thank You", isSpend: false),
            makeTxn(amount: 75, primary: nil, name: "Corner Store"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.bucket == .rest)
        #expect(result.first?.totalAmount == 75)
    }

    @Test func effectiveDateOutsideWindowIsExcluded() {
        let txns = [
            makeTxn(
                amount: 77.51,
                primary: "GENERAL_MERCHANDISE",
                date: "2026-05-24",
                authorizedDate: "2026-04-30"
            ),
            makeTxn(
                amount: 40,
                primary: "GENERAL_MERCHANDISE",
                date: "2026-05-24",
                authorizedDate: "2026-05-24"
            ),
        ]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: txns,
            trackedCategories: [],
            startDate: "2026-05-01",
            endDate: "2026-05-24"
        )

        #expect(result.count == 1)
        #expect(result.first?.totalAmount == 40)
    }

    @Test func unmappedPlaidCategoryGoesToRest() {
        let txns = [
            makeTxn(amount: 120, primary: "BANK_FEES"),
            makeTxn(amount: 80, primary: "FOOD_AND_DRINK"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let rest = result.first(where: { $0.bucket == .rest })
        #expect(rest?.totalAmount == 120)
    }

    @Test func transferOutWithNoSubcategoryIsExcluded() {
        // TRANSFER_OUT with unknown/missing subcategory — DB sets is_spend = false (safe default)
        let txns = [
            makeTxn(amount: 500, primary: "TRANSFER_OUT", isSpend: false),
            makeTxn(amount: 200, primary: "TRANSFER_IN", isSpend: false),
            makeTxn(amount: 40, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        #expect(result.first?.bucket == .category(.fun))
        #expect(result.first?.totalAmount == 40)
    }

    // MARK: - Aggregation

    @Test func multipleTransactionsSameCategoryAreAggregated() {
        let txns = [
            makeTxn(amount: 15, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 25, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 10, primary: "FOOD_AND_DRINK"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.count == 1)
        let item = result.first!
        #expect(item.totalAmount == 50)
        #expect(item.transactionCount == 3)
    }

    // MARK: - Percentage

    @Test func percentOfTotalCalculatedCorrectly() {
        let txns = [
            makeTxn(amount: 75, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 25, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let eats = result.first(where: { $0.bucket == .category(.eatsOut) })!
        let fun = result.first(where: { $0.bucket == .category(.fun) })!
        #expect(abs(eats.percentOfTotal - 0.75) < 0.001)
        #expect(abs(fun.percentOfTotal - 0.25) < 0.001)
    }

    @Test func percentOfTotalSumsToOne() {
        let txns = [
            makeTxn(amount: 40, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
            makeTxn(amount: 20, primary: "TRANSPORTATION"),
            makeTxn(amount: 10, primary: "GENERAL_MERCHANDISE"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        let totalPercent = result.reduce(0) { $0 + $1.percentOfTotal }
        #expect(abs(totalPercent - 1.0) < 0.001)
    }

    // MARK: - Default sort (amount descending)

    @Test func defaultSortPutsHighestAmountFirst() {
        let txns = [
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
            makeTxn(amount: 80, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 50, primary: "TRANSPORTATION"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result[0].totalAmount >= result[1].totalAmount)
        #expect(result[1].totalAmount >= result[2].totalAmount)
    }

    // MARK: - Rest always last

    @Test func restBucketIsAlwaysLastRegardlessOfAmount() {
        let txns = [
            makeTxn(amount: 500, primary: "BANK_FEES"),  // unmapped -> rest (highest)
            makeTxn(amount: 50, primary: "FOOD_AND_DRINK"),
            makeTxn(amount: 30, primary: "ENTERTAINMENT"),
        ]

        let result = CategoryBreakdownBuilder.build(currentTransactions: txns, trackedCategories: [])

        #expect(result.last?.bucket == .rest)
        #expect(result.last?.totalAmount == 500)
    }

    // MARK: - Previous period comparison (trends)

    @Test func trendPercentCalculatedFromPreviousPeriod() {
        let current = [makeTxn(amount: 110, primary: "FOOD_AND_DRINK")]
        let previous = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: []
        )

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        #expect(item.trendPercent != nil)
        // 10% increase
        #expect(abs((item.trendPercent ?? 0) - 0.1) < 0.001)
        #expect(item.isTrendUp == true)
    }

    @Test func downwardTrendIsCorrect() {
        let current = [makeTxn(amount: 80, primary: "FOOD_AND_DRINK")]
        let previous = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: []
        )

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        // 20% decrease
        #expect(abs((item.trendPercent ?? 0) - (-0.2)) < 0.001)
        #expect(item.isTrendUp == false)
    }

    @Test func trendPercentIsNilWhenNoPreviousData() {
        let current = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: [],
            trackedCategories: []
        )

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        #expect(item.trendPercent == nil)
        #expect(item.isTrendUp == nil)
    }

    @Test func nearlyFlatTrendReturnsNilForIsTrendUp() {
        let current = [makeTxn(amount: 100.5, primary: "FOOD_AND_DRINK")]
        let previous = [makeTxn(amount: 100.0, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: []
        )

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        // 0.5% change < 1% threshold → flat
        #expect(item.isTrendUp == nil)
        #expect(item.formattedTrend == "flat")
    }

    @Test func exactlyFlatTrendFormatsAsFlat() {
        let current = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]
        let previous = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: []
        )

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        #expect(item.formattedTrend == "flat")
    }

    @Test func formattedTrendIsNilWhenNoPreviousData() {
        let current = [makeTxn(amount: 100, primary: "FOOD_AND_DRINK")]

        let result = CategoryBreakdownBuilder.build(currentTransactions: current, trackedCategories: [])

        let item = result.first(where: { $0.bucket == .category(.eatsOut) })!
        #expect(item.formattedTrend == nil)
    }

    @Test func restBucketTrendUsesAggregatedPreviousAmount() {
        let current = [
            makeTxn(amount: 50, primary: "BANK_FEES"),
            makeTxn(amount: 30, primary: "BANK_FEES"),
        ]
        let previous = [
            makeTxn(amount: 40, primary: "BANK_FEES"),
            makeTxn(amount: 20, primary: "BANK_FEES"),
        ]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: []
        )

        let rest = result.first(where: { $0.bucket == .rest })!
        #expect(rest.totalAmount == 80)
        #expect(rest.previousAmount == 60)
    }

    @Test func previousOnlyBucketsAreIncludedForCushionDrivers() {
        let current = [
            makeTxn(amount: 50.52, primary: "TRANSPORTATION", detailed: "TRANSPORTATION_GAS"),
            makeTxn(amount: 23.20, primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES"),
        ]
        let previous = [
            makeTxn(amount: 55.26, primary: "RENT_AND_UTILITIES", detailed: "RENT_AND_UTILITIES_TELEPHONE"),
            makeTxn(amount: 4.99, primary: "ENTERTAINMENT", detailed: "ENTERTAINMENT_TV_AND_MOVIES"),
        ]

        let result = CategoryBreakdownBuilder.build(
            currentTransactions: current,
            previousTransactions: previous,
            trackedCategories: [],
            includePreviousOnly: true
        )

        let rest = result.first(where: { $0.bucket == .rest })
        let fun = result.first(where: { $0.bucket == .category(.fun) })
        let transit = result.first(where: { $0.bucket == .category(.gettingAround) })
        let groceries = result.first(where: { $0.bucket == .category(.groceries) })

        #expect(rest?.totalAmount == 0)
        #expect(rest?.previousAmount == 55.26)
        #expect(fun?.totalAmount == 0)
        #expect(fun?.previousAmount == 4.99)
        #expect(transit?.previousAmount == nil)
        #expect(groceries?.previousAmount == nil)
        #expect(result.count == 4)
    }

    // MARK: - SpendingBucket identity

    @Test func spendingBucketCategoryIdMatchesRawValue() {
        let bucket = SpendingBucket.category(.eatsOut)
        #expect(bucket.id == "eats_out")
    }

    @Test func spendingBucketRestId() {
        #expect(SpendingBucket.rest.id == "rest")
    }

    @Test func categoryBreakdownItemIdMatchesBucketId() {
        let item = CategoryBreakdownItem(
            bucket: .category(.fun),
            totalAmount: 50,
            transactionCount: 3,
            percentOfTotal: 0.5,
            previousAmount: nil
        )
        #expect(item.id == "fun")
    }

    // MARK: - Empty transactions

    @Test func emptyTransactionsReturnsEmptyBreakdown() {
        let result = CategoryBreakdownBuilder.build(currentTransactions: [], trackedCategories: [])
        #expect(result.isEmpty)
    }
}
