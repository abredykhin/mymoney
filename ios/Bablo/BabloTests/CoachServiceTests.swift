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

    private static func budgetState(
        poolRemaining: Double,
        dailyPace: Double = 18,
        weeklyPace: Double = 126,
        spentWeek: Double = 142,
        daysRemaining: Int = 18
    ) -> BudgetStateRow {
        BudgetStateRow(
            poolTotal: 900,
            poolRemaining: poolRemaining,
            dailyPace: dailyPace,
            weeklyPace: weeklyPace,
            spentToday: 0,
            spentWeek: spentWeek,
            spentMtd: 360,
            prevDaySpent: 0,
            prevWeekSpent: 102,
            prevMonthSpent: 820,
            effectiveIncome: 5_000,
            mandatory: 3_700,
            goalsSetAside: 0,
            netCash: 1_200,
            upcomingBills: 0,
            incomeBasis: .projected,
            daysInMonth: 30,
            daysRemaining: daysRemaining,
            daysElapsedInWeek: 5,
            knownIncome: 5_000,
            extraIncome: 0
        )
    }

    private static func goal(
        name: String = "Japan",
        pct: Double = 42,
        weeklyRate: Double = 24,
        thisMonth: Double = 96
    ) -> GoalSummaryItem {
        GoalSummaryItem(
            id: 1,
            name: name,
            categoryIcon: "✈️",
            targetAmount: 2_000,
            currentAmount: 840,
            etaDate: "2026-10-01",
            isActive: true,
            color: "#A9F236",
            priority: 0,
            pct: pct,
            weeklyRate: weeklyRate,
            thisMonth: thisMonth,
            statusLabel: "on_track",
            fundingMode: "auto_stash",
            monthlyContribution: 96
        )
    }

    // MARK: - Fast Unit Tests (Offline)

    // Medium tier (pace lens): a want that fits the week gets a green light.
    @Test func testCanIPurchaseApprovesMediumWhenItFitsTheWeek() {
        let decision = CoachPurchaseDecisionEngine.evaluate(
            preset: .medium,
            amount: 48,
            budgetState: Self.budgetState(poolRemaining: 312),
            habit: CoachHabitSignal(label: "Shop", spend: 142, transactionCount: 2, trendPercent: 0.38),
            primaryGoal: Self.goal()
        )

        #expect(decision.verdict == .go)
        #expect(decision.safeAfterPurchase == 264)
        #expect(decision.goalName == "Japan")
        #expect(decision.headline == "Fits the week. Go for it.")
        #expect(decision.reason.contains("on pace"))
    }

    // Small tier (habit lens): a cheap buy that's a repeated habit draining a hungry goal → caution.
    @Test func testCanIPurchaseWarnsWhenCheapItemIsARepeatedHabitAndGoalNeedsCash() {
        let decision = CoachPurchaseDecisionEngine.evaluate(
            preset: .small,
            amount: 6,
            budgetState: Self.budgetState(poolRemaining: 80, dailyPace: 5, weeklyPace: 35),
            habit: CoachHabitSignal(label: "Coffee", spend: 42, transactionCount: 6, trendPercent: 0.22),
            primaryGoal: Self.goal(pct: 12, weeklyRate: 60, thisMonth: 0)
        )

        #expect(decision.verdict == .caution)
        #expect(decision.safeAfterPurchase == 74)
        #expect(decision.goalName == "Japan")
        #expect(decision.headline == "The price is tiny. The pattern is not.")
        #expect(decision.reason.contains("6x"))
    }

    // Large tier (shock lens): a big-ticket buy that overshoots the cushion → skip.
    @Test func testCanIPurchaseBlocksWhenLargeBuyOvershootsCushion() {
        let decision = CoachPurchaseDecisionEngine.evaluate(
            preset: .large,
            amount: 124,
            budgetState: Self.budgetState(poolRemaining: 72, dailyPace: 4, weeklyPace: 28),
            habit: CoachHabitSignal(label: "Shop", spend: 220, transactionCount: 3, trendPercent: nil),
            primaryGoal: Self.goal(name: "Emergency", pct: 8, weeklyRate: 75, thisMonth: 10)
        )

        #expect(decision.verdict == .skip)
        #expect(decision.safeAfterPurchase == -52)
        #expect(decision.goalName == "Emergency")
        #expect(decision.headline == "Not this month.")
        #expect(decision.reason.contains("overshoots"))
    }

    // The verdict is measured against the trajectory-aware committed cushion when provided —
    // a buy that fits the naive pool can still be a skip once habit burn is subtracted.
    @Test func testCanIPurchaseUsesCommittedSafeWhenProvided() {
        let decision = CoachPurchaseDecisionEngine.evaluate(
            preset: .medium,
            amount: 40,
            budgetState: Self.budgetState(poolRemaining: 300),
            habit: CoachHabitSignal(label: "Shop", spend: 80, transactionCount: 2, trendPercent: nil),
            primaryGoal: Self.goal(),
            committedSafe: 25   // habits already claim most of the $300 pool
        )

        #expect(decision.verdict == .skip)
        #expect(decision.safeAfterPurchase == -15)
    }

    @Test @MainActor func testFetchCoachMissionsQueriesRPC() async throws {
        let mockData = """
        {
          "missions": [
            {
              "id": 11,
              "user_id": "user-1",
              "mission_type": "coffee_cap",
              "title": "3-day coffee cap",
              "icon": "☕",
              "target_goal_id": 1,
              "goal_name": "Japan",
              "start_date": "2026-06-07",
              "end_date": "2026-06-09",
              "projected_savings": 24,
              "actual_savings": 0,
              "status": "active",
              "completed_days": 1,
              "total_days": 3,
              "created_at": "2026-06-07T03:00:00Z",
              "updated_at": "2026-06-07T03:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_coach_missions"))

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }

        let service = CoachService(supabaseClient: Self.mockSupabaseClient())
        try await service.fetchMissions()

        #expect(service.missions.count == 1)
        #expect(service.missions.first?.missionType == .coffeeCap)
        #expect(service.missions.first?.goalName == "Japan")
        #expect(service.missions.first?.completedDays == 1)
    }

    @Test @MainActor func testStartCoffeeMissionQueriesRPCAndStoresActiveMission() async throws {
        let mockData = """
        {
          "id": 12,
          "user_id": "user-1",
          "mission_type": "coffee_cap",
          "title": "3-day coffee cap",
          "icon": "☕",
          "target_goal_id": 1,
          "goal_name": "Japan",
          "start_date": "2026-06-07",
          "end_date": "2026-06-09",
          "projected_savings": 24,
          "actual_savings": 0,
          "status": "active",
          "completed_days": 0,
          "total_days": 3,
          "created_at": "2026-06-07T03:00:00Z",
          "updated_at": "2026-06-07T03:00:00Z"
        }
        """.data(using: .utf8)!

        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/start_coach_mission"))

            let body = try #require(request.httpBodyStream?.readAllData())
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["p_mission_type"] as? String == "coffee_cap")
            #expect(json["p_target_goal_id"] as? Int == 1)
            #expect(json["p_projected_savings"] as? Double == 24)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }

        let service = CoachService(supabaseClient: Self.mockSupabaseClient())
        let mission = try await service.startCoffeeMission(goalId: 1, projectedSavings: 24)

        #expect(mission.id == 12)
        #expect(mission.status == .active)
        #expect(service.missions.map(\.id).contains(12))
    }

    @Test @MainActor func testCompleteMissionCanReturnGoalDeposit() async throws {
        let mockData = """
        {
          "mission": {
            "id": 12,
            "user_id": "user-1",
            "mission_type": "coffee_cap",
            "title": "3-day coffee cap",
            "icon": "☕",
            "target_goal_id": 1,
            "goal_name": "Japan",
            "start_date": "2026-06-07",
            "end_date": "2026-06-09",
            "projected_savings": 24,
            "actual_savings": 24,
            "status": "completed",
            "completed_days": 3,
            "total_days": 3,
            "created_at": "2026-06-07T03:00:00Z",
            "updated_at": "2026-06-10T03:00:00Z"
          },
          "deposit": {
            "id": 7,
            "goal_id": 1,
            "user_id": "user-1",
            "amount": 24,
            "deposit_date": "2026-06-10",
            "created_at": "2026-06-10T03:00:00Z"
          }
        }
        """.data(using: .utf8)!

        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/complete_coach_mission"))

            let body = try #require(request.httpBodyStream?.readAllData())
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["p_mission_id"] as? Int == 12)
            #expect(json["p_actual_savings"] as? Double == 24)
            #expect(json["p_stash"] as? Bool == true)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }

        let service = CoachService(supabaseClient: Self.mockSupabaseClient())
        service.missions = [
            CoachMission(
                id: 12,
                userId: "user-1",
                missionType: .coffeeCap,
                title: "3-day coffee cap",
                icon: "☕",
                targetGoalId: 1,
                goalName: "Japan",
                startDate: "2026-06-07",
                endDate: "2026-06-09",
                projectedSavings: 24,
                actualSavings: 0,
                status: .active,
                completedDays: 2,
                totalDays: 3,
                createdAt: "2026-06-07T03:00:00Z",
                updatedAt: "2026-06-07T03:00:00Z"
            )
        ]

        let completion = try await service.completeMission(id: 12, actualSavings: 24, stashToGoal: true)

        #expect(completion.mission.status == .completed)
        #expect(completion.deposit?.amount == 24)
        #expect(service.missions.first?.status == .completed)
    }

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
        guard await TestSupabaseClient.isAvailable() else { return }
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

    private static func mockSupabaseClient() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        return SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
    }
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while hasBytesAvailable {
            let count = read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }

        return data
    }
}
