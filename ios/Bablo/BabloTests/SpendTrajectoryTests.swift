//
//  SpendTrajectoryTests.swift
//  BabloTests
//
//  Tests for the deterministic Spend Trajectory projection (Coach revamp).
//

import Testing
import Foundation
@testable import Bablo

@Suite(.serialized)
struct SpendTrajectoryTests {

    private func row(
        primary: String?,
        sub: String? = nil,
        mtd: Double,
        avg: Double,
        count: Int = 1
    ) -> SpendTrajectoryRow {
        SpendTrajectoryRow(
            primaryCategory: primary,
            subcategory: sub,
            mtdSpent: mtd,
            trailingAvgMonthly: avg,
            txnCountMtd: count
        )
    }

    // The headline case: $500 spent so far against a $3,000/mo habit projects to $3,000, not a
    // naive linear extrapolation — and erases a $2,000 "safe" pool down to a negative cushion.
    @Test func amazonHabitProjectsToHistoricalRate() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "GENERAL_MERCHANDISE", mtd: 500, avg: 3000, count: 4)
        ])

        let shopping = try! #require(trajectory.items.first)
        #expect(shopping.bucket == .category(.shopping))
        #expect(shopping.projectedMonthEnd == 3000)
        #expect(shopping.projectedRemaining == 2500)
        #expect(trajectory.totalProjectedRemaining == 2500)
        #expect(trajectory.committedSafeToSpend(poolRemaining: 2000) == -500)
    }

    // Sub-pairs that map to the SAME bucket must be summed BEFORE the max() projection — projecting
    // each pair then summing would give the wrong number.
    @Test func subPairsInSameBucketSumBeforeProjection() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "GENERAL_MERCHANDISE", sub: "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES", mtd: 300, avg: 1000),
            row(primary: "HOME_IMPROVEMENT", sub: "HOME_IMPROVEMENT_HARDWARE", mtd: 200, avg: 2000)
        ])

        // Both map to .shopping → mtd 500, avg 3000, projected 3000, remaining 2500.
        #expect(trajectory.items.count == 1)
        let shopping = try! #require(trajectory.items.first)
        #expect(shopping.bucket == .category(.shopping))
        #expect(shopping.mtdSpent == 500)
        #expect(shopping.projectedMonthEnd == 3000)
        #expect(shopping.projectedRemaining == 2500)
    }

    // When the user has already outspent their historical rate, there is no future burn to project.
    @Test func mtdAboveAverageProjectsNoRemaining() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "FOOD_AND_DRINK", mtd: 4000, avg: 3000)
        ])

        let eats = try! #require(trajectory.items.first)
        #expect(eats.projectedMonthEnd == 4000)
        #expect(eats.projectedRemaining == 0)
        #expect(trajectory.totalProjectedRemaining == 0)
        // No burn left → committed cushion equals the naive pool.
        #expect(trajectory.committedSafeToSpend(poolRemaining: 1000) == 1000)
    }

    // Items are sorted by projected *remaining* (biggest threat first); topDriver picks it.
    @Test func topDriverIsLargestProjectedRemaining() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "FOOD_AND_DRINK", mtd: 100, avg: 400),          // eats: remaining 300
            row(primary: "GENERAL_MERCHANDISE", mtd: 200, avg: 1700),    // shopping: remaining 1500
            row(primary: "ENTERTAINMENT", mtd: 50, avg: 120)             // fun: remaining 70
        ])

        let driver = try! #require(trajectory.topDriver)
        #expect(driver.bucket == .category(.shopping))
        #expect(driver.projectedRemaining == 1500)
        #expect(trajectory.items.map(\.bucket) == [
            .category(.shopping), .category(.eatsOut), .category(.fun)
        ])
    }

    // Unmapped discretionary categories fall into the catch-all .rest bucket and still project.
    @Test func unmappedCategoryFallsToRestAndProjects() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "BANK_FEES", mtd: 20, avg: 60)
        ])

        let rest = try! #require(trajectory.items.first)
        #expect(rest.bucket == .rest)
        #expect(rest.projectedRemaining == 40)
    }

    // Subcategory keyword routing (coffee) is honored, matching the rest of the app's bucketing.
    @Test func coffeeSubcategoryRoutesToCoffeeRuns() {
        let trajectory = SpendTrajectory.build(rows: [
            row(primary: "FOOD_AND_DRINK", sub: "FOOD_AND_DRINK_COFFEE", mtd: 30, avg: 90),
            row(primary: "FOOD_AND_DRINK", sub: "FOOD_AND_DRINK_RESTAURANT", mtd: 100, avg: 200)
        ])

        // Two distinct buckets: coffeeRuns and eatsOut.
        let buckets = Set(trajectory.items.map(\.bucket))
        #expect(buckets == [.category(.coffeeRuns), .category(.eatsOut)])
    }

    @Test func emptyRowsProduceEmptyTrajectory() {
        let trajectory = SpendTrajectory.build(rows: [])
        #expect(trajectory.items.isEmpty)
        #expect(trajectory.totalProjectedRemaining == 0)
        #expect(trajectory.topDriver == nil)
        #expect(trajectory.committedSafeToSpend(poolRemaining: 500) == 500)
    }
}
