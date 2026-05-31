//
//  SubscriptionsServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct SubscriptionsServiceTests {
    
    @Test @MainActor func testFetchSubscriptions() async throws {
        // Intercept network call to fetch subscriptions and all recurring streams
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            #expect(url.query?.contains("user_id=eq.") == true)
            
            if url.path.contains("/rest/v1/active_subscription_streams") {
                let streamsJSON = """
                [
                  {
                    "id": 101,
                    "description": "Netflix",
                    "merchant_name": "Netflix",
                    "frequency": "MONTHLY",
                    "average_amount": 15.99,
                    "monthly_amount": 15.99,
                    "type": "expense",
                    "status": "MATURE",
                    "is_active": true,
                    "is_user_modified": false,
                    "user_marked_recurring": null,
                    "is_excluded": false,
                    "is_manual": false,
                    "match_pattern": null
                  }
                ]
                """
                return (response, streamsJSON.data(using: .utf8)!)
            } else if url.path.contains("/rest/v1/active_mandatory_expense_streams") {
                let streamsJSON = """
                [
                  {
                    "id": 102,
                    "description": "Rent",
                    "merchant_name": "Rent",
                    "frequency": "MONTHLY",
                    "average_amount": 1500.0,
                    "monthly_amount": 1500.0,
                    "type": "expense",
                    "status": "MATURE",
                    "is_active": true,
                    "is_user_modified": false,
                    "user_marked_recurring": null,
                    "is_excluded": false,
                    "is_manual": false,
                    "match_pattern": null
                  }
                ]
                """
                return (response, streamsJSON.data(using: .utf8)!)
            }
            
            return (response, "[]".data(using: .utf8)!)
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        
        let service = SubscriptionsService(supabaseClient: client)
        
        // Mock current user
        UserAccount.shared.currentUser = Bablo.User(
            id: "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
            name: "Test User",
            token: "mock_token",
            email: "test@example.com"
        )
        
        // Assert initial state is empty
        #expect(service.subscriptions.isEmpty)
        #expect(service.allRecurringStreams.isEmpty)
        
        // Fetch
        try await service.fetchSubscriptions()
        
        // Assert loaded from the database-filtered subscriptions endpoint.
        #expect(service.subscriptions.count == 1)
        #expect(service.subscriptions.first?.description == "Netflix")
        
        // Assert all recurring streams loaded.
        #expect(service.allRecurringStreams.count == 1)
        #expect(service.allRecurringStreams.first?.description == "Rent")
    }

    @Test @MainActor func fetchSubscriptionsDoesNotDuplicateSubscriptionFilteringWhenViewIsMissing() async throws {
        // The service now legitimately queries recurring_streams_table for income streams.
        // This test only flags it as a problem if the query lacks the income-type filter,
        // which would indicate the service is falling back to subscription filtering there.
        var didQueryRecurringForSubscriptions = false

        MockURLProtocol.mockHandler = { request in
            let url = request.url!

            if url.path.contains("/rest/v1/active_subscription_streams") {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let errorJSON = #"{"code":"42P01","message":"relation \"public.active_subscription_streams\" does not exist"}"#
                return (response, Data(errorJSON.utf8))
            }

            if url.path.contains("/rest/v1/recurring_streams_table") {
                // Income stream query is legitimate; subscription fallback is not.
                let isIncomeQuery = url.query?.contains("type=eq.income") == true
                if !isIncomeQuery {
                    didQueryRecurringForSubscriptions = true
                    Issue.record("client should not query raw recurring streams for subscription filtering")
                }
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: isIncomeQuery ? 200 : 500,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("[]".utf8))
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("[]".utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = SubscriptionsService(supabaseClient: client)

        UserAccount.shared.currentUser = Bablo.User(
            id: "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
            name: "Test User",
            token: "mock_token",
            email: "test@example.com"
        )

        do {
            try await service.fetchSubscriptions()
            Issue.record("Expected the missing database view error to be surfaced")
        } catch {
            // The app should rely on the database view instead of duplicating
            // subscription candidate logic against raw recurring streams.
        }

        #expect(!didQueryRecurringForSubscriptions)
        #expect(service.subscriptions.isEmpty)
    }

    @Test @MainActor func testScanIdleSubscriptions() async throws {
        // Intercept network call for idle scan
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            if url.path.contains("/rest/v1/recurring_streams_table") {
                Issue.record("Subscriptions should be loaded from the database-level active_subscription_streams view")
            }

            if url.path.contains("/rest/v1/active_subscription_streams") {
                let streamsJSON = """
                [
                  {
                    "id": 102,
                    "description": "Audible Premium",
                    "frequency": "MONTHLY",
                    "average_amount": 14.95,
                    "monthly_amount": 14.95,
                    "type": "expense",
                    "status": "MATURE",
                    "is_active": true,
                    "is_user_modified": false,
                    "user_marked_recurring": null,
                    "is_excluded": false,
                    "is_manual": false,
                    "match_pattern": null
                  }
                ]
                """
                return (response, streamsJSON.data(using: .utf8)!)
            } else if url.path.contains("/rest/v1/recurring_stream_transactions_table") {
                return (response, "[]".data(using: .utf8)!)
            }
            
            return (response, "[]".data(using: .utf8)!)
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        
        let service = SubscriptionsService(supabaseClient: client)
        
        // Mock current user
        UserAccount.shared.currentUser = Bablo.User(
            id: "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
            name: "Test User",
            token: "mock_token",
            email: "test@example.com"
        )
        
        // Assert initial state is 0
        #expect(service.idleCount == 0)
        
        // Scan
        await service.scanIdleSubscriptions()
        
        // Assert scanned idle using the database-filtered subscriptions endpoint.
        #expect(service.idleCount == 1)
        #expect(service.idleSubscriptionIDs == [102])
    }

    @Test func subscriptionDetailSummaryUsesIdleIdsForCountsAndSavings() {
        let streams = [
            createStream(id: 1, name: "Spotify", monthlyAmount: 11.99, category: "ENTERTAINMENT", subcategory: "MUSIC"),
            createStream(id: 2, name: "Netflix", monthlyAmount: 15.49, category: "ENTERTAINMENT", subcategory: "VIDEO"),
            createStream(id: 3, name: "Figma", monthlyAmount: 12.00, category: "GENERAL_SERVICES", subcategory: "CREATIVE")
        ]

        let summary = SubsDetailSummary(
            streams: streams,
            idleSubscriptionIDs: [2, 3],
            fallbackIdleCount: 0
        )

        #expect(abs(summary.totalMonthlyCost - 39.48) < 0.001)
        #expect(summary.activeCount == 1)
        #expect(summary.idleCount == 2)
        #expect(abs(summary.idleMonthlyCost - 27.49) < 0.001)
        #expect(summary.sortedStreams.map(\.id) == [2, 3, 1])
        #expect(summary.categoryBreakdowns.map(\.title) == ["Video", "Work", "Music"])
    }

    @Test func subscriptionRowMetadataUsesChargeLanguageInsteadOfUsageLanguage() {
        let calendar = Calendar.bablo
        let currentDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        let stream = createStream(
            id: 1,
            name: "Spotify",
            monthlyAmount: 11.99,
            category: "ENTERTAINMENT",
            subcategory: "MUSIC",
            lastDate: "2026-05-27"
        )

        let metadata = SubsStreamRowMetadata(
            stream: stream,
            isIdle: false,
            currentDate: currentDate
        )

        #expect(metadata.statusText == "CHARGED MAY 27")
    }
}

private func createStream(
    id: Int,
    name: String,
    monthlyAmount: Double,
    category: String,
    subcategory: String?,
    lastDate: String? = nil,
    predictedNextDate: String? = nil
) -> RecurringStream {
    RecurringStream(
        id: id,
        plaidStreamId: "plaid_\(id)",
        description: name,
        merchantName: name,
        personalFinanceCategory: category,
        personalFinanceSubcategory: subcategory,
        frequency: "MONTHLY",
        averageAmount: monthlyAmount,
        monthlyAmount: monthlyAmount,
        isoCurrencyCode: "USD",
        type: "expense",
        status: "MATURE",
        isActive: true,
        firstDate: nil,
        lastDate: lastDate,
        predictedNextDate: predictedNextDate,
        isUserModified: false,
        userMarkedRecurring: nil,
        isExcluded: false,
        isManual: false,
        matchPattern: nil,
        accountId: nil
    )
}
