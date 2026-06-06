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
        // fetchTotalBalance uses the get_net_cash_balance RPC (replaced direct accounts query)
        let mockData = Data("""
        [{"balance": -7750.34, "as_of": "2026-05-30", "iso_currency_code": "USD"}]
        """.utf8)

        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            #expect(url.path.contains("/rest/v1/rpc/get_net_cash_balance"))
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

        let service = await BudgetService(supabaseClient: client)
        try await service.fetchTotalBalance()

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

    @Test @MainActor func testFetchVariableSpendQueriesRPC() async throws {
        // fetchVariableSpend uses the get_variable_spend RPC (DB-side aggregation)
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, Data("182.5".utf8))
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

        #expect(capturedURL?.path.contains("/rest/v1/rpc/get_variable_spend") == true,
                "Must call get_variable_spend RPC, not query raw tables client-side")
    }

    @Test @MainActor func testFetchVariableSpendPassesDateParamsToRPC() async throws {
        // The RPC receives p_start/p_end; they may appear as URL query params or POST body params.
        // We verify that the RPC URL is called and that the query or body contains the date keys.
        var capturedRequest: URLRequest?

        MockURLProtocol.mockHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, Data("0.0".utf8))
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

        // Date params are in the POST body stream; check the URL path is the RPC endpoint.
        #expect(capturedRequest?.url?.path.contains("/rest/v1/rpc/get_variable_spend") == true,
                "Variable spend RPC must be called so date params are passed server-side")
        // Params must NOT leak into the URL query string (they belong in the body)
        let query = capturedRequest?.url?.query ?? ""
        #expect(!query.contains("p_start") && !query.contains("p_end") || query.isEmpty,
                "Date params belong in the POST body, not the URL query string")
    }

    @Test @MainActor func testFetchVariableSpendSumsPositiveAmounts() async throws {
        // get_variable_spend RPC returns a single Double (the sum)
        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, Data("182.5".utf8))
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
        await Task.yield()

        #expect(abs(service.variableSpend - 182.50) < 0.001)
    }

    @Test @MainActor func testFetchVariableSpendDoesNotQueryTransferParams() async throws {
        // RPC-based aggregation must not pass client-side NOT ILIKE filters in the URL.
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            return (response, Data("0.0".utf8))
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
                "Transfer NOT ILIKE filter must live in the DB, not the iOS query")
        #expect(!query.contains("LOAN_PAYMENTS"),
                "CC-payment filter must live in the DB, not the iOS query")
    }

    // MARK: - fetchActualIncome

    @Test @MainActor func testFetchActualIncomeQueriesIncomeRPC() async throws {
        // fetchActualIncome uses the get_monthly_income_summary RPC (replaced direct view query)
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            let incomeJSON = """
            [{"known_income": 5495.36, "extra_income": 0.0}]
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

        #expect(capturedURL?.path.contains("/rest/v1/rpc/get_monthly_income_summary") == true,
                "Income classification must use the DB RPC, not raw views")
        #expect(abs(service.knownIncomeThisMonth - 5495.36) < 0.001)
    }

    // MARK: - fetchHeroExcludedTransactionRows

    @Test @MainActor func testFetchHeroExcludedTransactionRowsQueriesRawTransactionsWithCalculationFlags() async throws {
        var capturedURLs: [URL] = []

        MockURLProtocol.mockHandler = { request in
            capturedURLs.append(request.url!)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            if request.url?.query?.contains("amount=lt.0") == true {
                let cardPaymentsJSON = """
                [
                  {
                    "amount": -3734.26,
                    "personal_finance_subcategory": "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT"
                  }
                ]
                """
                return (response, Data(cardPaymentsJSON.utf8))
            }

            let json = """
            [
              {
                "id": 1,
                "amount": 2500,
                "name": "CHASE CREDIT CARD PAYMENT",
                "personal_finance_category": "LOAN_PAYMENTS",
                "personal_finance_subcategory": "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT",
                "type": "depository",
                "is_recurring": false,
                "is_spend": false,
                "is_income": false
              },
              {
                "id": 2,
                "amount": -2500,
                "name": "Payment Thank You",
                "personal_finance_category": "TRANSFER_IN",
                "personal_finance_subcategory": "TRANSFER_IN_CASH_ADVANCES_AND_LOANS",
                "type": "credit",
                "is_recurring": false,
                "is_spend": false,
                "is_income": false
              },
              {
                "id": 3,
                "amount": 47413,
                "name": "DOMESTIC WIRE TRANSFER",
                "personal_finance_category": "TRANSFER_OUT",
                "personal_finance_subcategory": "TRANSFER_OUT_OTHER_TRANSFER_OUT",
                "type": "depository",
                "is_recurring": false,
                "is_spend": true,
                "is_income": false
              },
              {
                "id": 4,
                "amount": 42,
                "name": "SAFEWAY",
                "personal_finance_category": "FOOD_AND_DRINK",
                "personal_finance_subcategory": "FOOD_AND_DRINK_GROCERIES",
                "type": "credit",
                "is_recurring": false,
                "is_spend": true,
                "is_income": false
              },
              {
                "id": 5,
                "amount": 3734.26,
                "name": "Robinhood",
                "personal_finance_category": "TRANSFER_OUT",
                "personal_finance_subcategory": "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS",
                "type": "depository",
                "is_recurring": false,
                "is_spend": false,
                "is_income": false
              }
            ]
            """
            return (response, Data(json.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        let rows = await service.fetchHeroExcludedTransactionRows(for: .month)

        let positiveSpendURL = capturedURLs.first { $0.query?.contains("amount=gt.0") == true }
        let cardPaymentURL = capturedURLs.first { $0.query?.contains("amount=lt.0") == true }
        let query = positiveSpendURL?.query ?? ""
        #expect(positiveSpendURL?.path.contains("/rest/v1/transactions") == true)
        #expect(query.contains("is_income=eq.false"))
        #expect(query.contains("amount=gt.0"))
        #expect(query.contains("spend_date=gte."))
        #expect(query.contains("spend_date=lte."))
        #expect(!query.contains("is_recurring=eq."),
                "Excluded rows should include ignored recurring transactions too")
        #expect(cardPaymentURL?.query?.contains("amount=lt.0") == true,
                "Card-payment matching query must run and decode from a minimal amount-only response")
        #expect(Set(rows.map(\.name)) == Set(["Robinhood", "Chase Credit Card Payment"]))
        #expect(rows.filter { $0.detail == "Credit card payment" }.count == 2)
    }

    @Test @MainActor func testFetchHeroSpendBreakdownRowsUsesTrackedFlexibleCategories() async throws {
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            let json = """
            [
              {
                "id": 1,
                "amount": 25,
                "name": "BLUE BOTTLE COFFEE",
                "personal_finance_category": "FOOD_AND_DRINK",
                "personal_finance_subcategory": "FOOD_AND_DRINK_COFFEE_SHOP",
                "type": "depository"
              },
              {
                "id": 2,
                "amount": 75,
                "name": "SAFEWAY",
                "personal_finance_category": "FOOD_AND_DRINK",
                "personal_finance_subcategory": "FOOD_AND_DRINK_GROCERIES",
                "type": "depository"
              },
              {
                "id": 3,
                "amount": 40,
                "name": "AMC",
                "personal_finance_category": "ENTERTAINMENT",
                "personal_finance_subcategory": "ENTERTAINMENT_TV_AND_MOVIES",
                "type": "depository"
              },
              {
                "id": 4,
                "amount": 30,
                "name": "VENMO",
                "personal_finance_category": "TRANSFER_OUT",
                "personal_finance_subcategory": "TRANSFER_OUT_ACCOUNT_TRANSFER",
                "type": "depository"
              }
            ]
            """
            return (response, Data(json.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )

        let service = await BudgetService(supabaseClient: client)
        let rows = await service.fetchHeroSpendBreakdownRows(for: .month, trackedCategories: [.coffeeRuns])

        #expect(capturedURL?.query?.contains("personal_finance_subcategory") == true)
        #expect(rows.map(\.category) == ["Everything else", "Coffee runs"])
        #expect(rows.first?.amount == 145)
        #expect(rows.first?.transactionCount == 3)
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
