//
//  StreakServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct StreakServiceTests {
    
    private func loadFixture(name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturePath = sourceFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixturePath)
    }
    
    @Test @MainActor func testFetchUserStreak() async throws {
        // 1. Load mock user streak data
        let mockData = try loadFixture(name: "user_streak")
        
        // 2. Intercept RPC network call
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_user_spending_streak"))
            
            let response = HTTPURLResponse(
                url: url,
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
        
        let service = StreakService(supabaseClient: client)
        
        // Assert: initial state is nil
        #expect(service.userStreak == nil)
        
        // 3. Execute
        try await service.fetchUserStreak()
        
        // 4. Assert results (Red phase: this should fail because fetchUserStreak is currently a stub)
        #expect(service.userStreak != nil)
        #expect(service.userStreak?.currentStreak == 5)
        #expect(service.userStreak?.maxStreak == 12)
    }

    @Test @MainActor func fetchUserStreakLeavesStreakEmptyWhenBackendReturnsNoRows() async throws {
        let service = StreakService(supabaseClient: makeMockClient(returning: Data("[]".utf8)))

        try await service.fetchUserStreak()

        #expect(service.userStreak == nil)
    }

    @Test @MainActor func fetchUserStreakCapsBackendStreakAtNinetyDays() async throws {
        let response = Data("""
        [
            {
                "current_streak": 91,
                "max_streak": 91,
                "last_10_days_status": [true, true, true, true, true, true, true, true, true, true]
            }
        ]
        """.utf8)
        let service = StreakService(supabaseClient: makeMockClient(returning: response))

        try await service.fetchUserStreak()

        #expect(service.userStreak?.currentStreak == 90)
        #expect(service.userStreak?.maxStreak == 90)
    }

    private func makeMockClient(returning data: Data) -> SupabaseClient {
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_user_spending_streak"))

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        return SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
    }
}
