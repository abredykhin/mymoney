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
            categoryIcon: "🏄"
        )
        
        #expect(createdGoal.name == testGoalName)
        #expect(createdGoal.targetAmount == 3000.00)
        #expect(createdGoal.currentAmount == 0.00)

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
