//
//  CoachServiceTests.swift
//  BabloTests
//
//  Created for Supabase Migration - Phase 3
//  Tests for AI Coach Insights
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct CoachServiceTests {
    
    private func loadFixture(name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturePath = sourceFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixturePath)
    }

    // MARK: - Fast Unit Tests (Offline)

    @Test @MainActor func testCoachInsightsUnit() async throws {
        // 1. Load mock coach insights JSON
        let mockData = try loadFixture(name: "coach_insight")

        // 2. Intercept network request
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/functions/v1/gemini-coach-insights"))
            
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }

        // 3. Configure mock client
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        // 4. Initialize service and load
        let service = CoachService(supabaseClient: client)
        let insight = try await service.fetchCoachInsights()

        // 5. Assert math is correct
        #expect(service.currentInsight != nil)
        #expect(insight.badge == "COACH • INSIGHT")
        #expect(insight.headline == "Track your variable pace")
        #expect(insight.nudgeText.contains("dining out"))
        #expect(insight.actionLabel == "View Pacing")
        #expect(insight.alternativeTip.contains("meal"))
    }

    @Test @MainActor func testCoachInsightsDismissal() async throws {
        // 1. Configure service
        let service = CoachService(supabaseClient: TestSupabaseClient.shared)
        
        // 2. Initial state: not dismissed
        #expect(service.isDismissed == false)
        
        // 3. Dismiss it
        service.dismissInsight()
        #expect(service.isDismissed == true)
        
        // 4. Test resetting dismissal on new fetch
        let mockData = try loadFixture(name: "coach_insight")
        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        let mockService = CoachService(supabaseClient: client)
        mockService.isDismissed = true
        
        _ = try await mockService.fetchCoachInsights()
        #expect(mockService.isDismissed == false)
    }

    // MARK: - Live Local DB Integration Tests

    @Test @MainActor func testLiveCoachInsightsIntegration() async throws {
        let client = TestSupabaseClient.shared

        // 1. Authenticate as the seeded user
        _ = try await client.auth.signIn(email: "test@example.com", password: "password")

        // 2. Initialize live service
        let service = CoachService(supabaseClient: client)

        // 3. Fetch Coach insights from live local Edge Function
        let insight = try await service.fetchCoachInsights()
        
        // 4. Assert returned model structure is complete
        #expect(service.currentInsight != nil)
        #expect(insight.badge.isEmpty == false)
        #expect(insight.headline.isEmpty == false)
        #expect(insight.nudgeText.isEmpty == false)
        #expect(insight.actionLabel.isEmpty == false)
        #expect(insight.alternativeTip.isEmpty == false)
    }
}
