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
        // Intercept network call to fetch subscriptions
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            #expect(url.path.contains("/rest/v1/active_subscription_streams"))
            #expect(url.query?.contains("user_id=eq.") == true)
            
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
        
        // Fetch
        try await service.fetchSubscriptions()
        
        // Assert loaded from the database-filtered subscriptions endpoint.
        #expect(service.subscriptions.count == 1)
        #expect(service.subscriptions.first?.description == "Netflix")
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
    }
}
