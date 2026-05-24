//
//  PulseServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct PulseServiceTests {
    private func loadFixture(name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturePath = sourceFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixturePath)
    }

    private static func makeMockClient() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        return SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
    }

    @Test @MainActor func testFetchDamageReportUsesDailyStatsRPC() async throws {
        let mockData = try loadFixture(name: "daily_transaction_stats")
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, mockData)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())

        try await service.fetchDamageReport(startDate: "2026-05-13", endDate: "2026-05-19")

        #expect(capturedURL?.path.contains("/rest/v1/rpc/get_daily_transaction_stats") == true,
                "Damage report should use the existing account-type-aware daily stats RPC")
    }

    @Test @MainActor func testFetchDamageReportAggregatesInOutAndNet() async throws {
        let mockData = try loadFixture(name: "daily_transaction_stats")

        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, mockData)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())

        try await service.fetchDamageReport(startDate: "2026-05-13", endDate: "2026-05-19")

        #expect(service.damageReport?.totalIn == 612)
        #expect(service.damageReport?.totalOut == 387.42)
        #expect(abs((service.damageReport?.net ?? 0) - 224.58) < 0.001)
        #expect(service.damageReport?.formattedSpent == "$387.42")
        #expect(service.damageReport?.formattedNet == "+$225")
    }

    @Test @MainActor func testFetchDamageReportStoresPreviousWeekDelta() async throws {
        let currentWeek = """
        [
          { "date": "2026-05-13", "total_in": 612.00, "total_out": 387.42 }
        ]
        """.data(using: .utf8)!
        let previousWeek = """
        [
          { "date": "2026-05-06", "total_in": 240.00, "total_out": 311.42 }
        ]
        """.data(using: .utf8)!
        var requestCount = 0

        MockURLProtocol.mockHandler = { request in
            requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, requestCount == 1 ? currentWeek : previousWeek)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())

        try await service.fetchDamageReport(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            comparisonStartDate: "2026-05-06",
            comparisonEndDate: "2026-05-12"
        )

        #expect(service.damageReport?.spentDeltaFromPrevious == 76)
        #expect(service.damageReport?.formattedSpentDelta == "+$76 vs last wk")
    }

    // MARK: - Category breakdown

    @Test @MainActor func testFetchCategoryBreakdownQueriesTransactionsView() async throws {
        let transactionJSON = """
        [{
          "id": 1, "account_id": 1, "amount": 55.0, "date": "2026-05-13",
          "authorized_date": null, "name": "Chipotle", "merchant_name": "Chipotle",
          "pending": false, "category": null, "transaction_id": "tx_1",
          "pending_transaction_transaction_id": null, "iso_currency_code": "USD",
          "payment_channel": null, "user_id": null, "logo_url": null, "website": null,
          "personal_finance_category": "FOOD_AND_DRINK",
          "personal_finance_subcategory": "FOOD_AND_DRINK_RESTAURANT",
          "created_at": null, "updated_at": null
        }]
        """.data(using: .utf8)!

        var capturedPath: String?
        MockURLProtocol.mockHandler = { request in
            capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, transactionJSON)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())
        try await service.fetchCategoryBreakdown(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            trackedCategories: []
        )

        #expect(capturedPath?.contains("/rest/v1/transactions") == true,
                "Category breakdown should query the transactions view")
    }

    @Test @MainActor func testFetchCategoryBreakdownPopulatesBreakdownItems() async throws {
        let transactionJSON = """
        [
          {
            "id": 1, "account_id": 1, "amount": 55.0, "date": "2026-05-13",
            "authorized_date": null, "name": "Chipotle", "merchant_name": "Chipotle",
            "pending": false, "category": null, "transaction_id": "tx_1",
            "pending_transaction_transaction_id": null, "iso_currency_code": "USD",
            "payment_channel": null, "user_id": null, "logo_url": null, "website": null,
            "personal_finance_category": "FOOD_AND_DRINK",
            "personal_finance_subcategory": "FOOD_AND_DRINK_RESTAURANT",
            "created_at": null, "updated_at": null
          },
          {
            "id": 2, "account_id": 1, "amount": 25.0, "date": "2026-05-14",
            "authorized_date": null, "name": "Uber", "merchant_name": "Uber",
            "pending": false, "category": null, "transaction_id": "tx_2",
            "pending_transaction_transaction_id": null, "iso_currency_code": "USD",
            "payment_channel": null, "user_id": null, "logo_url": null, "website": null,
            "personal_finance_category": "TRANSPORTATION",
            "personal_finance_subcategory": "TRANSPORTATION_TAXIS_AND_RIDE_SHARES",
            "created_at": null, "updated_at": null
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, transactionJSON)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())
        try await service.fetchCategoryBreakdown(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            trackedCategories: []
        )

        let breakdown = try #require(service.categoryBreakdown)
        #expect(breakdown.isEmpty == false)

        let eats = breakdown.first(where: { $0.bucket == .category(.eatsOut) })
        let transit = breakdown.first(where: { $0.bucket == .category(.gettingAround) })
        #expect(eats?.totalAmount == 55)
        #expect(transit?.totalAmount == 25)

        // Percentages should add up to 1
        let totalPct = breakdown.reduce(0.0) { $0 + $1.percentOfTotal }
        #expect(abs(totalPct - 1.0) < 0.001)
    }

    @Test @MainActor func testFetchCategoryBreakdownRespectsTrackedCategories() async throws {
        let transactionJSON = """
        [
          {
            "id": 1, "account_id": 1, "amount": 50.0, "date": "2026-05-13",
            "authorized_date": null, "name": "Chipotle", "merchant_name": "Chipotle",
            "pending": false, "category": null, "transaction_id": "tx_1",
            "pending_transaction_transaction_id": null, "iso_currency_code": "USD",
            "payment_channel": null, "user_id": null, "logo_url": null, "website": null,
            "personal_finance_category": "FOOD_AND_DRINK",
            "personal_finance_subcategory": "FOOD_AND_DRINK_RESTAURANT",
            "created_at": null, "updated_at": null
          },
          {
            "id": 2, "account_id": 1, "amount": 20.0, "date": "2026-05-14",
            "authorized_date": null, "name": "Uber", "merchant_name": "Uber",
            "pending": false, "category": null, "transaction_id": "tx_2",
            "pending_transaction_transaction_id": null, "iso_currency_code": "USD",
            "payment_channel": null, "user_id": null, "logo_url": null, "website": null,
            "personal_finance_category": "TRANSPORTATION",
            "personal_finance_subcategory": null,
            "created_at": null, "updated_at": null
          }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.mockHandler = { _ in
            let response = HTTPURLResponse(url: URL(string: "http://127.0.0.1")!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, transactionJSON)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())
        // Only track eatsOut — transportation goes to Rest
        try await service.fetchCategoryBreakdown(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            trackedCategories: [.eatsOut]
        )

        let breakdown = try #require(service.categoryBreakdown)
        let eats = breakdown.first(where: { $0.bucket == .category(.eatsOut) })
        let rest = breakdown.first(where: { $0.bucket == .rest })
        #expect(eats != nil)
        #expect(rest?.totalAmount == 20)
    }

    @Test @MainActor func testFetchDamageReportDoesNotShowDeltaWithoutData() async throws {
        let emptyStats = "[]".data(using: .utf8)!

        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, emptyStats)
        }

        let service = PulseService(supabaseClient: Self.makeMockClient())

        try await service.fetchDamageReport(
            startDate: "2026-05-24",
            endDate: "2026-05-24",
            comparisonStartDate: "2026-05-23",
            comparisonEndDate: "2026-05-23"
        )

        #expect(service.damageReport?.totalOut == 0)
        #expect(service.damageReport?.spentDeltaFromPrevious == nil)
        #expect(service.damageReport?.formattedSpentDelta == nil)
    }
}
