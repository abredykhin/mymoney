//
//  GoalsServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct GoalsServiceTests {
    
    private func loadFixture(name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturePath = sourceFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixturePath)
    }

    private func mockClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> SupabaseClient {
        MockURLProtocol.mockHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        return SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
    }

    // MARK: - Fast Unit Tests (Offline)

    @Test @MainActor func testGoalsPacingUnit() async throws {
        // 1. Load mock savings goals JSON
        let mockData = try loadFixture(name: "savings_goals")

        // 2. Intercept network request
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/savings_goals_table"))
            
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
        let service = GoalsService(supabaseClient: client)
        try await service.fetchSavingsGoals()

        // 5. Assert math is correct
        #expect(service.savingsGoals.count == 1)
        let goal = service.savingsGoals[0]
        #expect(goal.name == "Tokyo Trip")
        #expect(goal.targetAmount == 5000.00)
        #expect(goal.currentAmount == 1250.00)
        #expect(goal.progressPercent == 0.25)
    }

    @Test @MainActor func testWithdrawFromGoalUsesBoundedRpcAndReturnsNegativeDeposit() async throws {
        let mockData = Data("""
        {
          "id": 42,
          "goal_id": 7,
          "user_id": "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
          "amount": -75.0,
          "deposit_date": "2026-06-10",
          "created_at": "2026-06-10T12:00:00Z"
        }
        """.utf8)

        var capturedBody: [String: Any] = [:]
        let client = mockClient { request in
            let url = request.url!
            if url.path.contains("/rest/v1/rpc/get_goals_summary") {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data(Self.emptySummaryJSON.utf8))
            }
            #expect(url.path.contains("/rest/v1/rpc/withdraw_from_goal"))
            let body = try #require(request.httpBodyStream?.readAllData())
            capturedBody = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }

        let service = GoalsService(supabaseClient: client)
        let withdrawal = try await service.withdrawFromGoal(goalId: 7, amount: 75)

        #expect(withdrawal.goalId == 7)
        #expect(withdrawal.amount == -75)
        #expect(capturedBody["p_goal_id"] as? Int == 7)
        #expect(capturedBody["p_amount"] as? Int == 75)
    }

    @Test @MainActor func testUpdateSavingsGoalCanSwitchToLinkedAccountFunding() async throws {
        var capturedBody: [String: Any] = [:]
        let client = mockClient { request in
            let url = request.url!
            if url.path.contains("/rest/v1/rpc/get_goals_summary") {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data(Self.emptySummaryJSON.utf8))
            }
            #expect(url.path.contains("/rest/v1/savings_goals_table"))
            #expect(request.httpMethod == "PATCH")
            let body = try #require(request.httpBodyStream?.readAllData())
            capturedBody = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

            let response = HTTPURLResponse(
                url: url,
                statusCode: 204,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data())
        }

        let service = GoalsService(supabaseClient: client)
        try await service.updateSavingsGoal(
            id: 7,
            name: "Emergency fund",
            targetAmount: 10_000,
            etaDate: nil,
            categoryIcon: "💰",
            color: "#A9F236",
            monthlyContribution: 0,
            fundingMode: .linked,
            linkedAccountId: 99
        )

        #expect(capturedBody["funding_mode"] as? String == "linked")
        #expect(capturedBody["linked_account_id"] as? Int == 99)
        #expect(capturedBody["monthly_contribution"] as? Int == 0)
    }

    @Test func testGoalFundingImpactShowsDailyPoolChange() {
        let impact = GoalFundingImpact(
            monthlyContribution: 310,
            daysRemaining: 31,
            currentDailyPace: 100
        )

        #expect(impact.monthlyPoolDelta == -310)
        #expect(impact.dailyPaceAfterContribution == 90)
        #expect(impact.dailyPaceDelta == -10)
    }

    private static let emptySummaryJSON = """
    {
      "total_stashed": 0,
      "total_target": 0,
      "funded_pct": 0,
      "goal_count": 0,
      "this_month": 0,
      "depository_balance": 0,
      "vault_covered": true,
      "goals": []
    }
    """

    // MARK: - Live Local DB Integration Tests (Mutating & Teardown Cleanse)

    @Test @MainActor func testLiveMutatingGoalsAndDeposits() async throws {
        guard await TestSupabaseClient.isAvailable() else { return }
        let client = TestSupabaseClient.shared

        // 1. Authenticate as the seeded user
        _ = try await client.auth.signIn(email: "test@example.com", password: "password")

        // 2. Initialize live service
        let service = GoalsService(supabaseClient: client)

        // 3. Targeted cleanup: remove any leftover [TEST] goals from crashed prior run
        try await service.fetchSavingsGoals()
        for goal in service.savingsGoals {
            if goal.name.hasPrefix("[TEST]") {
                try await service.deleteSavingsGoal(goalId: goal.id)
            }
        }

        // 4. Create a new test savings goal
        let testGoalName = "[TEST] Maui Surfing"
        let createdGoal = try await service.createSavingsGoal(
            name: testGoalName,
            targetAmount: 3000.00,
            etaDate: "2027-06-30",
            categoryIcon: "🏄",
            monthlyContribution: 200.00
        )

        #expect(createdGoal.name == testGoalName)
        #expect(createdGoal.targetAmount == 3000.00)
        #expect(createdGoal.currentAmount == 0.00)
        // Auto-stash (Mode B) round-trips and the BEFORE trigger stamps the accrual anchor.
        #expect(createdGoal.fundingMode == "auto_stash")
        #expect(createdGoal.monthlyContribution == 200.00)
        #expect(createdGoal.contributionStartedOn != nil)

        // 5. Add a deposit and verify the database trigger updates the main goal balance automatically
        let deposit = try await service.addDeposit(goalId: createdGoal.id, amount: 250.00)
        #expect(deposit.amount == 250.00)

        // Fetch again and verify balance matches the trigger update
        try await service.fetchSavingsGoals()
        let updatedGoal = service.savingsGoals.first(where: { $0.id == createdGoal.id })
        #expect(updatedGoal != nil)
        #expect(updatedGoal?.currentAmount == 250.00)
        #expect(updatedGoal?.progressPercent == 250.00 / 3000.00)

        // 6. Teardown: delete the test goal and verify it cascade-deletes the deposits cleanly
        try await service.deleteSavingsGoal(goalId: createdGoal.id)

        try await service.fetchSavingsGoals()
        let missingGoal = service.savingsGoals.first(where: { $0.id == createdGoal.id })
        #expect(missingGoal == nil)
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
