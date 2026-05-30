//
//  BudgetRPCTests.swift
//  BabloTests
//
//  Integration tests that verify each new DB aggregate RPC returns identical results
//  to the old client-side calculation it replaced.
//  Requires the local Supabase stack (supabase start) with seed data.
//

import Testing
import Foundation
import Supabase
@testable import Bablo

// MARK: - Shared auth helper

private func authenticatedClient() async throws -> SupabaseClient {
    let client = TestSupabaseClient.shared
    _ = try await client.auth.signIn(email: "test@example.com", password: "password")
    return client
}

// MARK: - Phase 1: get_net_cash_balance()

@Suite("get_net_cash_balance RPC")
struct NetCashBalanceRPCTests {

    private struct AccountRow: Codable {
        let currentBalance: Double
        let type: String
        enum CodingKeys: String, CodingKey {
            case currentBalance = "current_balance"
            case type
        }
    }

    /// The RPC must return the same net value as summing account rows client-side.
    @Test @MainActor func matchesClientSideCalculation() async throws {
        let client = try await authenticatedClient()

        // Old client-side path: fetch all rows, reduce in Swift
        let accounts: [AccountRow] = try await client
            .from("accounts")
            .select("current_balance, type")
            .eq("hidden", value: false)
            .execute()
            .value

        let expectedBalance = accounts.reduce(0.0) { result, account in
            if account.type.caseInsensitiveCompare("depository") == .orderedSame {
                return result + account.currentBalance
            } else if account.type.caseInsensitiveCompare("credit") == .orderedSame {
                return result - account.currentBalance
            }
            return result
        }

        // New RPC path
        let results: [TotalBalance] = try await client
            .rpc("get_net_cash_balance")
            .execute()
            .value

        #expect(results.count == 1, "RPC must return exactly one aggregate row")
        let rpcBalance = results.first?.balance ?? -999_999
        #expect(abs(rpcBalance - expectedBalance) < 0.005,
                "RPC balance \(rpcBalance) must match client-side \(expectedBalance)")
        #expect(results.first?.iso_currency_code == "USD")
    }

    /// The service convenience method must decode the RPC result into TotalBalance.
    @Test @MainActor func serviceMethodDecodesTotalBalance() async throws {
        let client = try await authenticatedClient()
        let service = BudgetService(supabaseClient: client)

        try await service.fetchTotalBalance()

        #expect(service.totalBalance != nil)
        #expect(service.totalBalance?.iso_currency_code == "USD")
        #expect(service.isLoadingBalance == false)
        #expect(service.balanceError == nil)
    }
}

// MARK: - Phase 2: get_spending_breakdown()

@Suite("get_spending_breakdown RPC")
struct SpendingBreakdownRPCTests {

    private struct TxRow: Codable {
        let amount: Double
        let personalFinanceCategory: String?
        enum CodingKeys: String, CodingKey {
            case amount
            case personalFinanceCategory = "personal_finance_category"
        }
    }

    private struct BreakdownRow: Codable {
        let category: String
        let totalSpent: Double
        let transactionCount: Int
        let percentOfTotal: Double
        enum CodingKeys: String, CodingKey {
            case category
            case totalSpent       = "total_spent"
            case transactionCount = "transaction_count"
            case percentOfTotal   = "percent_of_total"
        }
    }

    /// The RPC must return the same category totals as the old client-side GROUP BY.
    @Test @MainActor func matchesClientSideGroupBy() async throws {
        let client = try await authenticatedClient()
        let startDate = "2026-01-01"
        let endDate   = "2026-01-31"

        // Old client-side path: fetch all rows, group in Swift
        let transactions: [TxRow] = try await client
            .from("transactions")
            .select("amount, personal_finance_category")
            .gte("spend_date", value: startDate)
            .lte("spend_date", value: endDate)
            .eq("is_spend", value: true)
            .execute()
            .value

        var expectedMap: [String: Double] = [:]
        for tx in transactions {
            let cat = tx.personalFinanceCategory ?? "Uncategorized"
            expectedMap[cat, default: 0] += abs(tx.amount)
        }

        // New RPC path
        struct Params: Encodable { let p_start: String; let p_end: String }
        let rows: [BreakdownRow] = try await client
            .rpc("get_spending_breakdown", params: Params(p_start: startDate, p_end: endDate))
            .execute()
            .value

        #expect(!rows.isEmpty || expectedMap.isEmpty,
                "RPC must return rows when transactions exist")

        for row in rows {
            let expected = expectedMap[row.category] ?? 0
            #expect(abs(row.totalSpent - expected) < 0.005,
                    "Category \(row.category): RPC \(row.totalSpent) vs client \(expected)")
        }

        // percent_of_total must sum to ~100 (or 0 if no data)
        let totalPercent = rows.reduce(0.0) { $0 + $1.percentOfTotal }
        if !rows.isEmpty {
            #expect(abs(totalPercent - 100.0) < 0.01,
                    "percent_of_total must sum to 100, got \(totalPercent)")
        }
    }

    /// The service method must populate spendBreakdownResponse correctly.
    @Test @MainActor func serviceMethodPopulatesBreakdown() async throws {
        let client = try await authenticatedClient()
        let service = BudgetService(supabaseClient: client)

        try await service.fetchTotalSpend(range: .month)

        #expect(service.spendBreakdownResponse != nil)
        #expect(service.isLoadingBreakdown == false)
        #expect(service.breakdownError == nil)

        // Percentages must sum to ~100 when there is data
        if let breakdown = service.spendBreakdownResponse, !breakdown.breakdown.isEmpty {
            let pctSum = breakdown.breakdown.compactMap { $0.percentOfTotal }.reduce(0, +)
            #expect(abs(pctSum - 100.0) < 0.1)
        }
    }
}

// MARK: - Phase 3: get_variable_spend() and get_period_spend_comparison()

@Suite("get_variable_spend RPC")
struct VariableSpendRPCTests {

    private struct VarTxRow: Codable {
        let amount: Double
    }

    /// The scalar RPC must return the same sum as reducing variable_transactions client-side.
    @Test @MainActor func matchesClientSideSum() async throws {
        let client = try await authenticatedClient()
        let startDate = "2026-01-01"
        let endDate   = "2026-01-31"

        // Old path: fetch rows, sum in Swift
        let rows: [VarTxRow] = try await client
            .from("variable_transactions")
            .select("amount")
            .gte("spend_date", value: startDate)
            .lte("spend_date", value: endDate)
            .gt("amount", value: 0)
            .execute()
            .value
        let expectedTotal = rows.reduce(0.0) { $0 + abs($1.amount) }

        // New RPC path
        struct Params: Encodable { let p_start: String; let p_end: String }
        let rpcTotal: Double = try await client
            .rpc("get_variable_spend", params: Params(p_start: startDate, p_end: endDate))
            .execute()
            .value

        #expect(abs(rpcTotal - expectedTotal) < 0.005,
                "RPC \(rpcTotal) must match client-side \(expectedTotal)")
    }
}

@Suite("get_period_spend_comparison RPC")
struct PeriodSpendComparisonRPCTests {

    private struct PeriodRow: Codable {
        let prevWeek: Double
        let prevMonth: Double
        let currentWeek: Double
        let today: Double
        enum CodingKeys: String, CodingKey {
            case prevWeek    = "prev_week"
            case prevMonth   = "prev_month"
            case currentWeek = "current_week"
            case today
        }
    }

    /// The comparison RPC must return all four windows in one row and match
    /// four individual get_variable_spend calls for the same windows.
    @Test @MainActor func matchesFourIndividualCalls() async throws {
        let client = try await authenticatedClient()

        // Use a fixed reference date so the test is deterministic against seed data.
        let today          = "2026-01-27"
        let currentWkStart = "2026-01-25"  // Sunday of that week (US locale)
        let prevWkStart    = "2026-01-18"
        let prevWkSameDay  = "2026-01-27"  // Tuesday → prev Tue
        let prevMoStart    = "2025-12-01"
        let prevMoSameDay  = "2025-12-27"

        struct SingleParams: Encodable { let p_start: String; let p_end: String }

        async let wk  = (try await client.rpc("get_variable_spend",
            params: SingleParams(p_start: prevWkStart, p_end: prevWkSameDay)).execute().value) as Double
        async let mo  = (try await client.rpc("get_variable_spend",
            params: SingleParams(p_start: prevMoStart, p_end: prevMoSameDay)).execute().value) as Double
        async let cWk = (try await client.rpc("get_variable_spend",
            params: SingleParams(p_start: currentWkStart, p_end: today)).execute().value) as Double
        async let td  = (try await client.rpc("get_variable_spend",
            params: SingleParams(p_start: today, p_end: today)).execute().value) as Double

        let (expWk, expMo, expCWk, expTd) = try await (wk, mo, cWk, td)

        struct CompParams: Encodable {
            let p_prev_week_start: String
            let p_prev_week_same_day_end: String
            let p_prev_month_start: String
            let p_prev_month_same_day_end: String
            let p_current_week_start: String
            let p_today: String
        }
        let rows: [PeriodRow] = try await client
            .rpc("get_period_spend_comparison", params: CompParams(
                p_prev_week_start:         prevWkStart,
                p_prev_week_same_day_end:  prevWkSameDay,
                p_prev_month_start:        prevMoStart,
                p_prev_month_same_day_end: prevMoSameDay,
                p_current_week_start:      currentWkStart,
                p_today:                   today
            ))
            .execute()
            .value

        #expect(rows.count == 1, "comparison RPC must return exactly one row")
        guard let row = rows.first else { return }

        #expect(abs(row.prevWeek    - expWk)  < 0.005, "prev_week mismatch")
        #expect(abs(row.prevMonth   - expMo)  < 0.005, "prev_month mismatch")
        #expect(abs(row.currentWeek - expCWk) < 0.005, "current_week mismatch")
        #expect(abs(row.today       - expTd)  < 0.005, "today mismatch")
    }
}

// MARK: - Phase 4: get_monthly_income_summary()

@Suite("get_monthly_income_summary RPC")
struct MonthlyIncomeSummaryRPCTests {

    private struct IncomeTxRow: Codable {
        let amount: Double
        let isRecurring: Bool?
        enum CodingKeys: String, CodingKey {
            case amount
            case isRecurring = "is_recurring"
        }
    }

    private struct IncomeSummary: Codable {
        let knownIncome: Double
        let extraIncome: Double
        enum CodingKeys: String, CodingKey {
            case knownIncome = "known_income"
            case extraIncome = "extra_income"
        }
    }

    /// The RPC must return the same known/extra split as aggregating rows client-side.
    @Test @MainActor func matchesClientSideAggregation() async throws {
        let client = try await authenticatedClient()
        let startDate = "2026-01-01"
        let endDate   = "2026-01-31"

        // Old client-side path: fetch income rows, bucket in Swift
        let rows: [IncomeTxRow] = try await client
            .from("spendable_income_transactions")
            .select("amount, is_recurring")
            .gte("spend_date", value: startDate)
            .lte("spend_date", value: endDate)
            .execute()
            .value

        var expectedKnown = 0.0
        var expectedExtra = 0.0
        for row in rows {
            let amount = abs(row.amount)
            if row.isRecurring == true { expectedKnown += amount }
            else                       { expectedExtra += amount }
        }

        // New RPC path
        struct Params: Encodable { let p_start: String; let p_end: String }
        let summaries: [IncomeSummary] = try await client
            .rpc("get_monthly_income_summary",
                 params: Params(p_start: startDate, p_end: endDate))
            .execute()
            .value

        #expect(summaries.count == 1, "RPC must return exactly one summary row")
        guard let s = summaries.first else { return }

        #expect(abs(s.knownIncome - expectedKnown) < 0.005,
                "known_income \(s.knownIncome) must match client-side \(expectedKnown)")
        #expect(abs(s.extraIncome - expectedExtra) < 0.005,
                "extra_income \(s.extraIncome) must match client-side \(expectedExtra)")
        #expect(s.knownIncome >= 0)
        #expect(s.extraIncome >= 0)
    }

    /// The service method must populate the income properties correctly.
    @Test @MainActor func serviceMethodPopulatesIncomeProperties() async throws {
        let client = try await authenticatedClient()
        let service = BudgetService(supabaseClient: client)

        await service.fetchActualIncome()

        #expect(service.knownIncomeThisMonth >= 0)
        #expect(service.extraIncomeThisMonth >= 0)
    }
}
