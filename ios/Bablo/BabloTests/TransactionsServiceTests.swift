//
//  TransactionsServiceTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

@Suite(.serialized)
struct TransactionsServiceTests {
    
    @Test @MainActor func testFetchTransactionsExactTotalCount() async throws {
        // Intercept network call to fetch transactions
        MockURLProtocol.mockHandler = { request in
            let url = request.url!
            
            // Postgrest returns count in Content-Range header when exact count is requested
            // E.g. "0-1/100" means 2 items returned, but 100 total items in DB.
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "Content-Range": "items 0-1/100" // 100 total items
                ]
            )!
            
            #expect(url.path.contains("/rest/v1/transactions"))

            return (response, Self.twoTransactionsJSON.data(using: .utf8)!)
        }

        // Setup service with the mocked SupabaseClient
        let service = TransactionsService(supabaseClient: Self.makeMockClient())
        
        // Initially empty
        #expect(service.transactions.isEmpty)
        
        // Fetch recent transactions (limit 2)
        try await service.fetchRecentTransactions(forceRefresh: true, limit: 2)
        
        // Verify we parsed the transactions successfully
        #expect(service.transactions.count == 2)
        
        // Verify exact pagination total count (should be 100 as specified in the Content-Range header)
        #expect(service.paginationInfo?.totalCount == 100)
        #expect(service.paginationInfo?.isTotalCountExact == true)
        #expect(service.paginationInfo?.hasMore == true)
        #expect(service.paginationInfo?.nextOffset == 2)
    }

    @Test @MainActor func testFetchTransactionsExactFullLastPageDoesNotReportMore() async throws {
        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "Content-Range": "items 0-1/2"
                ]
            )!

            return (response, Self.twoTransactionsJSON.data(using: .utf8)!)
        }

        let service = TransactionsService(supabaseClient: Self.makeMockClient())

        try await service.fetchRecentTransactions(forceRefresh: true, limit: 2)

        #expect(service.paginationInfo?.totalCount == 2)
        #expect(service.paginationInfo?.isTotalCountExact == true)
        #expect(service.paginationInfo?.hasMore == false)
        #expect(service.paginationInfo?.nextOffset == nil)
    }

    @Test @MainActor func testFetchTransactionsMissingCountUsesLoadedLowerBound() async throws {
        MockURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json"
                ]
            )!

            return (response, Self.twoTransactionsJSON.data(using: .utf8)!)
        }

        let service = TransactionsService(supabaseClient: Self.makeMockClient())

        try await service.fetchTransactions(options: FetchOptions(limit: 2, offset: 50))

        #expect(service.transactions.count == 2)
        #expect(service.paginationInfo?.totalCount == 52)
        #expect(service.paginationInfo?.isTotalCountExact == false)
        #expect(service.paginationInfo?.hasMore == true)
        #expect(service.paginationInfo?.nextOffset == 52)
    }

    @Test @MainActor func testFetchTransactionsFiltersAndOrdersBySpendDate() async throws {
        var capturedURL: URL?

        MockURLProtocol.mockHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "Content-Range": "items 0-1/2"
                ]
            )!

            return (response, Self.twoTransactionsJSON.data(using: .utf8)!)
        }

        let service = TransactionsService(supabaseClient: Self.makeMockClient())
        let options = FetchOptions(
            limit: 2,
            filter: TransactionFilter(startDate: "2026-05-24", endDate: "2026-05-24")
        )

        try await service.fetchTransactions(options: options)

        let query = capturedURL?.query ?? ""
        #expect(query.contains("spend_date=gte.2026-05-24"),
                "Transaction date filtering must use canonical spend_date")
        #expect(query.contains("spend_date=lte.2026-05-24"),
                "Transaction date filtering must use canonical spend_date")
        #expect(query.contains("order=spend_date.desc"),
                "Transaction list ordering must follow canonical spend_date")
        #expect(!query.contains("?date=gte.") && !query.contains("&date=gte."),
                "Raw Plaid date can be future-dated for pending transactions")
    }
    
    @Test func testTransactionAmountSignFormatting() {
        let expense = Transaction(
            id: 1, account_id: 10, amount: 6.50, date: "2026-05-23", authorized_date: nil,
            name: "Blue Bottle Coffee", merchant_name: "Blue Bottle", pending: false, category: nil,
            transaction_id: "tx_1", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
            payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
            personal_finance_category: "FOOD_AND_DRINK", personal_finance_subcategory: nil,
            created_at: nil, updated_at: nil
        )
        
        let inflow = Transaction(
            id: 2, account_id: 10, amount: -24.00, date: "2026-05-22", authorized_date: nil,
            name: "Venmo Sam", merchant_name: "Venmo · Sam", pending: false, category: nil,
            transaction_id: "tx_2", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
            payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
            personal_finance_category: "INFLOW", personal_finance_subcategory: nil,
            created_at: nil, updated_at: nil
        )
        
        // Verify formattedAmount returns positive absolute value format e.g. "$6.50", "$24.00"
        #expect(expense.formattedAmount == "$6.50")
        #expect(inflow.formattedAmount == "$24.00")
        
        // Verify absoluteAmount
        #expect(expense.absoluteAmount == 6.50)
        #expect(inflow.absoluteAmount == 24.00)
        
        // Verify isExpense
        #expect(expense.isExpense == true)
        #expect(inflow.isExpense == false)
    }

    @Test func testRecentTransactionPresentationFormatsExpenseAndIncomeAndTransfer() {
        let expense = Transaction(
            id: 1, account_id: 10, amount: 6.50, date: "2026-05-23", authorized_date: nil,
            name: "Blue Bottle Coffee", merchant_name: "Blue Bottle", pending: false, category: nil,
            transaction_id: "tx_1", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
            payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
            personal_finance_category: "FOOD_AND_DRINK", personal_finance_subcategory: nil,
            created_at: nil, updated_at: nil
        )

        let income = Transaction(
            id: 2, account_id: 10, amount: -154.00, date: "2026-05-23", authorized_date: nil,
            name: "Paycheck", merchant_name: nil, pending: false, category: nil,
            transaction_id: "tx_2", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
            payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
            personal_finance_category: "INCOME", personal_finance_subcategory: nil,
            created_at: nil, updated_at: nil
        )

        let transfer = Transaction(
            id: 3, account_id: 10, amount: -4817.01, date: "2026-05-23", authorized_date: nil,
            name: "Manual CR-Bkrg", merchant_name: nil, pending: false, category: nil,
            transaction_id: "tx_3", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
            payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
            personal_finance_category: "INCOME", personal_finance_subcategory: "INCOME_WAGES",
            created_at: nil, updated_at: nil,
            is_spend: false, is_income: false
        )

        let expensePresentation = RecentTransactionPresentation(transaction: expense)
        let incomePresentation = RecentTransactionPresentation(transaction: income)
        let transferPresentation = RecentTransactionPresentation(transaction: transfer)

        #expect(expensePresentation.amountText == "-$6.50")
        #expect(incomePresentation.amountText == "+$154")
        #expect(transferPresentation.amountText == "+$4,817.01")
        #expect(expensePresentation.categoryText == "Food And Drink")
        #expect(transferPresentation.categoryText == "Transfer")
        #expect(incomePresentation.iconName == "arrow.down.circle.fill")
        #expect(transferPresentation.iconName == "arrow.left.arrow.right")
        
        #expect(expense.isSpend == true)
        #expect(expense.isIncome == false)
        #expect(income.isSpend == false)
        #expect(income.isIncome == true)
        #expect(transfer.isSpend == false)
        #expect(transfer.isIncome == false)
        #expect(transfer.isActualTransfer == true)
    }

    @Test func testFlexibleSpendingCategoriesProvideWritableTransactionCategoryPairs() {
        for category in FlexibleSpendingCategory.allCases {
            let write = category.transactionCategoryWrite

            #expect(FlexibleSpendingCategory.map(primary: write.primary, detailed: write.detailed) == category)
        }

        let transport = FlexibleSpendingCategory.gettingAround.transactionCategoryWrite
        #expect(transport.primary == "TRANSPORTATION")
        #expect(transport.detailed == "TRANSPORTATION_TAXIS_AND_RIDE_SHARES")
    }

    
    @Test func testTransactionDateEdgeCases() {
        func makeTx(date: String) -> Transaction {
            Transaction(
                id: 1, account_id: 10, amount: 6.50, date: date, authorized_date: nil,
                name: "Test", merchant_name: nil, pending: false, category: nil,
                transaction_id: "tx_1", pending_transaction_transaction_id: nil, iso_currency_code: "USD",
                payment_channel: nil, user_id: nil, logo_url: nil, website: nil,
                personal_finance_category: nil, personal_finance_subcategory: nil,
                created_at: nil, updated_at: nil
            )
        }
        
        // 1. Standard YYYY-MM-DD
        let tx1 = makeTx(date: "2026-05-23")
        #expect(tx1.formattedDate == "May 23, 2026")
        
        // 2. ISO 8601 with Z (UTC)
        let tx2 = makeTx(date: "2026-05-23T18:57:43.000Z")
        #expect(tx2.formattedDate == "May 23, 2026")
        
        // 3. ISO 8601 with offset
        let tx3 = makeTx(date: "2026-05-23T18:57:43-07:00")
        #expect(tx3.formattedDate == "May 23, 2026")
        
        // 4. Invalid date format - should safely fall back to the original string
        let tx4 = makeTx(date: "invalid-date-string")
        #expect(tx4.formattedDate == "invalid-date-string")
        
        // 5. Empty date string
        let tx5 = makeTx(date: "")
        #expect(tx5.formattedDate == "")
    }

    private static func makeMockClient() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        return SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH",
            options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
        )
    }

    private static let twoTransactionsJSON = """
    [
      {
        "id": 1,
        "account_id": 10,
        "amount": 6.50,
        "date": "2026-05-23",
        "authorized_date": null,
        "name": "Blue Bottle Coffee",
        "merchant_name": "Blue Bottle",
        "pending": false,
        "category": ["Food and Drink", "Restaurants", "Coffee Shop"],
        "transaction_id": "tx_123",
        "pending_transaction_transaction_id": null,
        "iso_currency_code": "USD",
        "payment_channel": "in store",
        "user_id": "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
        "logo_url": null,
        "website": null,
        "personal_finance_category": "FOOD_AND_DRINK",
        "personal_finance_subcategory": "FOOD_AND_DRINK_COFFEE_SHOP",
        "created_at": null,
        "updated_at": null
      },
      {
        "id": 2,
        "account_id": 10,
        "amount": -24.00,
        "date": "2026-05-22",
        "authorized_date": null,
        "name": "Venmo Sam",
        "merchant_name": "Venmo · Sam",
        "pending": false,
        "category": ["Transfer", "Debit"],
        "transaction_id": "tx_124",
        "pending_transaction_transaction_id": null,
        "iso_currency_code": "USD",
        "payment_channel": "online",
        "user_id": "5f6bb5c6-faf0-484f-aee1-23316a77ea90",
        "logo_url": null,
        "website": null,
        "personal_finance_category": "INFLOW",
        "personal_finance_subcategory": "INFLOW_TRANSFER",
        "created_at": null,
        "updated_at": null
      }
    ]
    """
}
