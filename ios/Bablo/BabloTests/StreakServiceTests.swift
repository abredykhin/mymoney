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

    @Test func streakDetailProgressTargetsTheNextMilestone() {
        let streak = UserStreak(
            currentStreak: 7,
            maxStreak: 12,
            last10DaysStatus: [true, true, false, true, true, true, true, false, true, true]
        )

        #expect(streak.nextMilestoneDay == 14)
        #expect(streak.daysToNextMilestone == 7)
        #expect(streak.milestoneProgress == 0.5)
    }

    @Test func streakDetailMilestonesUseOnlyCurrentProductRewards() {
        let streak = UserStreak(
            currentStreak: 30,
            maxStreak: 30,
            last10DaysStatus: Array(repeating: true, count: 10)
        )

        let milestones = streak.detailMilestones

        #expect(milestones.map(\.day) == [3, 7, 14, 30, 60])
        #expect(milestones.map(\.title).contains("$15 boost to a goal") == false)
        #expect(milestones.map(\.title).contains("$5 coffee, on Bablo") == false)
        #expect(milestones.first(where: { $0.day == 30 })?.isFeatured == true)
        #expect(milestones.first(where: { $0.day == 60 })?.isReached == false)
    }

    @Test func streakDetailCalendarPadsKnownStatusesIntoFiveWeekGrid() {
        let streak = UserStreak(
            currentStreak: 5,
            maxStreak: 5,
            last10DaysStatus: [true, false, true, true, true, false, true, true, true, true]
        )

        let cells = streak.detailCalendarCells

        #expect(cells.count == 35)
        #expect(cells.prefix(25).allSatisfy { $0.status == .unknown })
        #expect(cells.suffix(10).map(\.status) == [
            .underBudget,
            .underBudget,
            .underBudget,
            .underBudget,
            .overBudget,
            .underBudget,
            .underBudget,
            .underBudget,
            .overBudget,
            .today
        ])
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
