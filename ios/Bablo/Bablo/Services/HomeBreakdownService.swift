import Foundation
import Supabase

/// Fetches drill-down data for the Home screen's MoneyLeft and BreakdownTransactionList views.
/// All methods return values directly — there is no cached state.
@MainActor
class HomeBreakdownService: ObservableObject {
    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    // MARK: - Hero spend/income/excluded rows

    func fetchHeroSpendBreakdownRows(
        for period: HeroPeriod,
        trackedCategories: Set<FlexibleSpendingCategory> = [],
        limit: Int = 6
    ) async -> [HeroSpendBreakdownRow] {
        let window = heroDateWindow(for: period)

        do {
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("variable_transactions")
                .select("id, amount, name, personal_finance_category, personal_finance_subcategory, type")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .gt("amount", value: 0)
                .execute()
                .value

            var buckets: [String: (amount: Double, count: Int, examples: [String])] = [:]
            for transaction in transactions {
                let category = displaySpendBucket(
                    primary: transaction.personalFinanceCategory,
                    detailed: transaction.personalFinanceSubcategory,
                    trackedCategories: trackedCategories
                )
                var bucket = buckets[category] ?? (amount: 0, count: 0, examples: [])
                bucket.amount += abs(transaction.amount)
                bucket.count += 1
                let merchant = cleanMerchantName(transaction.name)
                if !merchant.isEmpty && !bucket.examples.contains(merchant) && bucket.examples.count < 2 {
                    bucket.examples.append(merchant)
                }
                buckets[category] = bucket
            }

            return buckets
                .map { category, bucket in
                    HeroSpendBreakdownRow(
                        category: category,
                        amount: bucket.amount,
                        transactionCount: bucket.count,
                        examples: bucket.examples
                    )
                }
                .sorted { $0.amount > $1.amount }
                .prefix(limit)
                .map { $0 }
        } catch {
            Logger.e("HomeBreakdownService: Failed to fetch hero spend rows: \(error)")
            return []
        }
    }

    func fetchHeroIncomeRowsForCurrentMonth(limit: Int = 4) async -> [HeroIncomeBreakdownRow] {
        let window = heroDateWindow(for: .month)

        do {
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("spendable_income_transactions")
                .select("amount, name, type, is_recurring, is_paycheck")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .execute()
                .value

            var groups: [String: (amount: Double, count: Int, isRecurring: Bool)] = [:]
            for tx in transactions where tx.type != "credit" && tx.type != "loan" {
                let key = cleanIncomeName(tx.name)
                var g = groups[key] ?? (amount: 0, count: 0, isRecurring: false)
                g.amount += abs(tx.amount)
                g.count += 1
                // A received paycheck reads as recurring even before Plaid links it to its
                // stream (is_paycheck), matching how the budget RPC counts it as known income.
                g.isRecurring = g.isRecurring || (tx.isRecurring == true) || (tx.isPaycheck == true)
                groups[key] = g
            }
            return groups
                .map { name, g in
                    let displayName = g.count > 1 ? "\(name) ×\(g.count)" : name
                    return HeroIncomeBreakdownRow(name: displayName, amount: g.amount, isRecurring: g.isRecurring)
                }
                .sorted { $0.amount > $1.amount }
                .prefix(limit)
                .map { $0 }
        } catch {
            Logger.e("HomeBreakdownService: Failed to fetch hero income rows: \(error)")
            return []
        }
    }

    func fetchHeroExcludedTransactionRows(for period: HeroPeriod, limit: Int = 6) async -> [HeroExcludedTransactionRow] {
        let window = heroDateWindow(for: period)

        do {
            let transactions: [TransactionForBreakdown] = try await supabase
                .from("transactions")
                .select("id, amount, name, personal_finance_category, personal_finance_subcategory, type, is_recurring, is_spend, is_income")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .gt("amount", value: 0)
                .eq("is_income", value: false)
                .order("amount", ascending: false)
                .limit(100)
                .execute()
                .value
            let cardPayments: [HeroCardPaymentMatch] = try await supabase
                .from("transactions")
                .select("amount, personal_finance_subcategory")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .lt("amount", value: 0)
                .eq("personal_finance_subcategory", value: "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT")
                .limit(100)
                .execute()
                .value
            let cardPaymentAmounts = Set(cardPayments.map { roundedCents(abs($0.amount)) })

            return transactions
                .filter { isExcludedFromHeroSpend($0) }
                .prefix(limit)
                .map { transaction in
                    HeroExcludedTransactionRow(
                        name: cleanMerchantName(transaction.name),
                        detail: exclusionReason(for: transaction, cardPaymentAmounts: cardPaymentAmounts),
                        amount: transaction.amount
                    )
                }
        } catch {
            Logger.e("HomeBreakdownService: Failed to fetch hero excluded transaction rows: \(error)")
            return []
        }
    }

    // MARK: - Transaction lists (drill-down navigation)

    func fetchVariableTransactionList(for period: HeroPeriod) async -> [Transaction] {
        let window = heroDateWindow(for: period)
        do {
            let transactions: [Transaction] = try await supabase
                .from("variable_transactions")
                .select("id, account_id, amount, date, authorized_date, authorized_datetime, datetime, spend_date, name, merchant_name, pending, transaction_id, iso_currency_code, personal_finance_category, personal_finance_subcategory, logo_url, payment_channel, user_id, website, created_at, updated_at, pending_transaction_transaction_id")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .gt("amount", value: 0)
                .order("spend_date", ascending: false)
                .order("amount", ascending: false)
                .execute()
                .value
            return transactions
        } catch {
            Logger.e("HomeBreakdownService: Failed to fetch variable transaction list: \(error)")
            return []
        }
    }

    func fetchIncomeTransactionList() async -> [Transaction] {
        let window = heroDateWindow(for: .month)
        do {
            let transactions: [Transaction] = try await supabase
                .from("spendable_income_transactions")
                .select("id, account_id, amount, date, authorized_date, authorized_datetime, datetime, spend_date, name, merchant_name, pending, transaction_id, iso_currency_code, personal_finance_category, personal_finance_subcategory, logo_url, payment_channel, user_id, website, created_at, updated_at, pending_transaction_transaction_id")
                .gte("spend_date", value: window.start)
                .lte("spend_date", value: window.end)
                .order("spend_date", ascending: false)
                .execute()
                .value
            return transactions
        } catch {
            Logger.e("HomeBreakdownService: Failed to fetch income transaction list: \(error)")
            return []
        }
    }

    // MARK: - Private helpers

    private func heroDateWindow(for period: HeroPeriod) -> (start: String, end: String) {
        switch period {
        case .day:
            let today = PreviousPeriodDateRange.compute(calendar: .bablo).todayDate
            return (today, today)
        case .week:
            let ranges = PreviousPeriodDateRange.compute(calendar: .bablo)
            return (ranges.currentWeekStart, ranges.todayDate)
        case .month:
            return (SpendDateRange.month.startDate(), SpendDateRange.month.endDate())
        }
    }

    private func displaySpendBucket(
        primary: String?,
        detailed: String?,
        trackedCategories: Set<FlexibleSpendingCategory>
    ) -> String {
        guard let category = FlexibleSpendingCategory.map(primary: primary, detailed: detailed) else {
            return "Everything else"
        }
        if trackedCategories.isEmpty || trackedCategories.contains(category) {
            return category.displayName
        }
        return "Everything else"
    }

    private func cleanMerchantName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = name.range(of: #"\*[A-Z0-9]+"#, options: .regularExpression) {
            name = String(name[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if name.uppercased().hasPrefix("NON-CHASE ATM") || name.uppercased().hasPrefix("NON CHASE ATM") {
            return "ATM Withdrawal"
        }
        if name.count > 4 && name == name.uppercased() {
            name = name.split(separator: " ").map { word -> String in
                let w = String(word)
                let lower = w.lowercased()
                let acronyms: Set<String> = ["llc", "atm", "ach", "ppd", "usa", "us", "nyc", "sf"]
                return acronyms.contains(lower) ? w.uppercased() : lower.prefix(1).uppercased() + lower.dropFirst()
            }.joined(separator: " ")
        }
        return name
    }

    private func cleanIncomeName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" PPD ID:", " ACH ID:", " WEB ID:", " CCD ID:", " TEL ID:"] {
            if let r = name.range(of: suffix) {
                name = String(name[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        for suffix in [" PAYROLL", " DIRECT DEP", " DIR DEP"] {
            if name.uppercased().hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        if name.count > 4 && name == name.uppercased() {
            name = name.split(separator: " ").map { word -> String in
                let w = String(word)
                let lower = w.lowercased()
                let acronyms: Set<String> = ["llc", "inc", "usa", "us", "atm"]
                return acronyms.contains(lower) ? w.uppercased() : lower.prefix(1).uppercased() + lower.dropFirst()
            }.joined(separator: " ")
        }
        return name
    }

    private func exclusionReason(for transaction: TransactionForBreakdown, cardPaymentAmounts: Set<Int> = []) -> String {
        let category = transaction.personalFinanceCategory ?? ""
        let subcategory = transaction.personalFinanceSubcategory ?? ""
        let name = transaction.name.lowercased()
        let type = transaction.type?.lowercased() ?? ""

        if subcategory == "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT" {
            return "Credit card payment"
        }
        if cardPaymentAmounts.contains(roundedCents(abs(transaction.amount))) &&
            (name.contains("card") || name.contains("citi") || name.contains("robinhood")) {
            return "Credit card payment"
        }
        if category == "TRANSFER_IN" || category == "TRANSFER_OUT" || name.contains("transfer") {
            if subcategory == "TRANSFER_OUT_OTHER_TRANSFER_OUT" {
                return "Already in cash balance; not variable spend"
            }
            return "Transfer between accounts"
        }
        if type == "investment" || subcategory.contains("INVESTMENT_AND_RETIREMENT") {
            return "Investment movement"
        }
        if transaction.amount <= 0 {
            return "Not spendable income"
        }
        return "Outside the safe-spend calculation"
    }

    private func isExcludedFromHeroSpend(_ transaction: TransactionForBreakdown) -> Bool {
        guard transaction.amount > 0 else { return false }
        return transaction.isSpend != true
    }

    private func roundedCents(_ amount: Double) -> Int {
        Int((amount * 100).rounded())
    }
}

// MARK: - Private models

private struct TransactionForBreakdown: Codable {
    let id: Int?
    let amount: Double
    let name: String
    let personalFinanceCategory: String?
    let personalFinanceSubcategory: String?
    let type: String?
    let isRecurring: Bool?
    let isSpend: Bool?
    let isIncome: Bool?
    let isPaycheck: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case name
        case personalFinanceCategory = "personal_finance_category"
        case personalFinanceSubcategory = "personal_finance_subcategory"
        case type
        case isRecurring = "is_recurring"
        case isSpend = "is_spend"
        case isIncome = "is_income"
        case isPaycheck = "is_paycheck"
    }
}

private struct HeroCardPaymentMatch: Codable {
    let amount: Double
    let personalFinanceSubcategory: String?

    enum CodingKeys: String, CodingKey {
        case amount
        case personalFinanceSubcategory = "personal_finance_subcategory"
    }
}
