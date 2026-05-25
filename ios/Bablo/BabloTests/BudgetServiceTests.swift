//
//  BudgetServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
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
        
        // 6. Assert result calculations (Net Cash = Depository $0.00 - Credit $7750.34 = -$7750.34)
        let total = service.totalBalance
        #expect(total != nil)
        #expect(total?.balance == -7750.34)
        #expect(total?.formattedBalance == "-$7,750.34")
    }
    
    @Test @MainActor func testFetchWeeklyEnergy() async throws {
        // 1. Load the contract-derived JSON mock
        let mockData = try loadFixture(name: "weekly_energy")
        
        // 2. Setup network interception
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_pulse_weekly_energy"))
            
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
        
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        
        // 4. Initialize the refactored service with the mock client
        let service = await BudgetService(supabaseClient: client)
        
        // 5. Execute weekly energy fetching
        try await service.fetchWeeklyEnergy(weekStart: "2026-01-20", weekEnd: "2026-01-27")
        
        // 6. Assert decodes and parsed structures correctly
        #expect(service.dailyEnergy.count == 8)
        let peakDay = service.dailyEnergy.first(where: { $0.isPeak })
        #expect(peakDay != nil)
        #expect(peakDay?.weekday == "Sat")
        #expect(peakDay?.peakMerchant == "European Market Deli & Cafe")
        #expect(peakDay?.totalSpent == 434.78)
        #expect(peakDay?.peakAmount == 218.4)
    }
    
    @Test @MainActor func testFetchTopMerchants() async throws {
        // 1. Load the contract-derived JSON mock
        let mockData = try loadFixture(name: "top_merchants")
        
        // 2. Setup network interception
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_pulse_top_merchants"))
            
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
        
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
        
        // 4. Initialize the refactored service with the mock client
        let service = await BudgetService(supabaseClient: client)
        
        // 5. Execute top merchants fetching
        try await service.fetchTopMerchants(startDate: "2026-01-01", endDate: "2026-01-27", limit: 5)
        
        // 6. Assert decodes and parsed structures correctly
        #expect(service.topMerchants.count == 5)
        let top = service.topMerchants[0]
        #expect(top.merchantName == "Romanov Law")
        #expect(top.totalSpent == 5000)
        #expect(top.transactionCount == 1)
        #expect(top.personalFinanceCategory == "GENERAL_SERVICES")
        
        let second = service.topMerchants[1]
        #expect(second.merchantName == "Safeway")
        #expect(second.totalSpent == 1205.98)
        #expect(second.transactionCount == 28)
    }
    

    // MARK: - fetchVariableSpend

    @Test @MainActor func testFetchVariableSpendQueriesCorrectView() async throws {
        let mockData = try loadFixture(name: "variable_transactions")
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, mockData)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        try? await service.fetchVariableSpend()

        #expect(capturedURL?.path.contains("/rest/v1/variable_transactions") == true,
                "Must query variable_transactions view, not raw transactions table")
    }

    @Test @MainActor func testFetchVariableSpendSumsPositiveAmounts() async throws {
        // Fixture has 3 expenses: $85.50 + $42.00 + $55.00 = $182.50
        let mockData = try loadFixture(name: "variable_transactions")

        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, mockData)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        try? await service.fetchVariableSpend()
        // fetchVariableSpend sets variableSpend via DispatchQueue.main.async — yield to let it run
        await Task.yield()

        #expect(abs(service.variableSpend - 182.50) < 0.001)
    }

    @Test @MainActor func testFetchVariableSpendDoesNotQueryTransferParams() async throws {
        // After moving filter logic to the DB view, the iOS query must not send
        // NOT ILIKE or subcategory filter params. "ilike" only appears in the URL
        // if a NOT ILIKE filter was added client-side.
        let mockData = try loadFixture(name: "variable_transactions")
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, mockData)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        try? await service.fetchVariableSpend()

        let query = capturedURL?.query ?? ""
        #expect(!query.contains("ilike"),
                "Transfer NOT ILIKE filter must live in the DB view, not the iOS query")
        #expect(!query.contains("LOAN_PAYMENTS"),
                "CC-payment filter must live in the DB view, not the iOS query")
    }

    // MARK: - fetchActualIncome

    @Test @MainActor func testFetchActualIncomeQueriesSpendableIncomeView() async throws {
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            let incomeJSON = """
            [
              {
                "id": 1,
                "amount": -5495.36,
                "name": "GOOGLE LLC PAYROLL PPD ID: J770493581",
                "personal_finance_category": "INCOME",
                "type": "depository",
                "is_recurring": false
              }
            ]
            """
            return (response, Data(incomeJSON.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        UserAccount.shared.currentUser = Bablo.User(
            id: "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
            name: "Test User",
            token: "mock_token",
            email: "test@example.com"
        )

        let service = await BudgetService(supabaseClient: client)
        await service.fetchActualIncome()

        #expect(capturedURL?.path.contains("/rest/v1/spendable_income_transactions") == true,
                "Income classification should live in the DB view, not raw transactions")
    }

    // MARK: - calculateVariableBudget

    @Test @MainActor func testCalculateVariableBudgetBasicCase() async throws {
        // income $5000, mandatory $2000, variableSpend $500 → variableBudget = $2500
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        service.monthlyIncome = 5000
        service.monthlyMandatoryExpenses = 2000
        service.variableSpend = 500
        // knownIncomeThisMonth = 0, extraIncomeThisMonth = 0
        // effectiveIncome = max(5000, 0) + 0 = 5000
        service.calculateVariableBudget()

        #expect(service.variableBudget == 2500)
    }

    @Test @MainActor func testCalculateVariableBudgetEffectiveIncomeUsesKnownWhenHigher() async throws {
        // Plaid detected $8200 this month vs profile $8000 — should use $8200
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        service.monthlyIncome = 8000
        service.knownIncomeThisMonth = 8200   // e.g., 3-paycheck month
        service.extraIncomeThisMonth = 0
        service.monthlyMandatoryExpenses = 3000
        service.variableSpend = 500
        service.calculateVariableBudget()

        // effectiveIncome = max(8000, 8200) + 0 = 8200
        #expect(service.variableBudget == 4700)
    }

    @Test @MainActor func testCalculateVariableBudgetExtraIncomeAdded() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        service.monthlyIncome = 5000
        service.knownIncomeThisMonth = 5000
        service.extraIncomeThisMonth = 1000   // freelance payment
        service.monthlyMandatoryExpenses = 2000
        service.variableSpend = 500
        service.calculateVariableBudget()

        // effectiveIncome = max(5000, 5000) + 1000 = 6000
        #expect(service.variableBudget == 3500)
    }
}
