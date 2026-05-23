//
//  BudgetServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

struct BudgetServiceTests {
    
    /// Utility to load JSON mock data using the local filesystem path (bypasses Xcode resource bundle registry)
    private func loadFixture(name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturePath = sourceFile.deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixturePath)
    }
    
    @Test @MainActor func testFetchTotalBalance() async throws {
        // 1. Load the contract-derived JSON mock
        let mockData = try loadFixture(name: "accounts")
        
        // 2. Setup network interception
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            // Assert that the client queried the correct table/view
            #expect(url.path.contains("/rest/v1/accounts"))
            
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockData)
        }
        
        // 3. Configure SupabaseClient with our MockURLProtocol session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        // SupabaseClient in Supabase-Swift accepts custom sessions in its ClientOptions
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        
        // 4. Initialize the refactored service with the mock client
        let service = await BudgetService(supabaseClient: client)
        
        // 5. Execute the variable budget balance retrieval
        try await service.fetchTotalBalance()
        
        // 6. Assert result calculations (Net Cash = Depository $12500.50 - Credit $3200.25 = $9300.25)
        let total = service.totalBalance
        #expect(total != nil)
        #expect(total?.balance == 9300.25)
        #expect(total?.formattedBalance == "$9,300.25")
    }
}
