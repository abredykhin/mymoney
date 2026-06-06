//
//  SubscriptionsService.swift
//  Bablo
//

import Foundation
import Supabase

@MainActor
class SubscriptionsService: ObservableObject {
    @Published var subscriptions: [RecurringStream] = []
    @Published var allRecurringStreams: [RecurringStream] = []
    @Published var idleCount: Int = 0
    @Published var idleSubscriptionIDs: Set<Int> = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetch active subscription expenses (expense recurring streams)
    func fetchSubscriptions() async throws {
        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetService.BudgetError.noUser
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let fetchSubs: [RecurringStream] = supabase
                .from("active_subscription_streams")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            async let fetchAllStreams: [RecurringStream] = supabase
                .from("active_mandatory_expense_streams")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            async let fetchIncomeStreams: [RecurringStream] = supabase
                .from("recurring_streams_table")
                .select("*")
                .eq("user_id", value: userId)
                .eq("type", value: "income")
                .eq("is_active", value: true)
                .eq("is_excluded", value: false)
                .neq("status", value: "TOMBSTONED")
                .execute()
                .value

            let (subs, expenses, incomes) = try await (fetchSubs, fetchAllStreams, fetchIncomeStreams)
            self.subscriptions = subs
            self.allRecurringStreams = expenses + incomes
            Logger.i("SubscriptionsService: Loaded \(subs.count) subscriptions, \(expenses.count) expense streams, and \(incomes.count) income streams")
        } catch {
            Logger.e("SubscriptionsService: Failed to fetch subscriptions: \(error)")
            self.error = error
            throw error
        }
    }

    /// Scan for idle subscriptions (expense streams with 0 transactions in past 45 days)
    func scanIdleSubscriptions() async {
        guard let userId = UserAccount.shared.currentUser?.id else { return }
        
        let calendar = Calendar.bablo
        let now = Date()
        guard let fortyFiveDaysAgo = calendar.date(byAdding: .day, value: -45, to: now) else { return }
        
        let dateFormatter = ISO8601DateFormatter()
        let fortyFiveDaysAgoStr = dateFormatter.string(from: fortyFiveDaysAgo)
        
        do {
            // 1. Fetch active expense streams if not loaded
            let streams = subscriptions.isEmpty ? try await supabase
                .from("active_subscription_streams")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value as [RecurringStream] : subscriptions

            // 2. Fetch all recent recurring stream transaction links within the last 45 days
            struct StreamTX: Codable {
                let stream_id: Int
            }
            let recentTXs: [StreamTX] = try await supabase
                .from("recurring_stream_transactions_table")
                .select("stream_id")
                .gte("created_at", value: fortyFiveDaysAgoStr)
                .execute()
                .value
            
            let activeStreamIds = Set(recentTXs.map { $0.stream_id })
            
            // 3. Any active expense stream NOT in the activeStreamIds set is "idle"
            let idleStreams = streams.filter { !activeStreamIds.contains($0.id) }
            self.idleSubscriptionIDs = Set(idleStreams.map(\.id))
            self.idleCount = idleStreams.count
            Logger.i("SubscriptionsService: Scanned \(streams.count) subscriptions, found \(idleCount) idle subscriptions")
        } catch {
            Logger.e("SubscriptionsService: Failed to scan idle subscriptions: \(error)")
        }
    }

    // MARK: - Upcoming bills helpers

    /// Total upcoming unpaid mandatory expenses in the next 14 days.
    var upcomingUnpaidBills: Double {
        let calendar = Calendar.bablo
        let now = Date()
        let todayStr = SpendDateRange.month.endDate()

        guard let fourteenDaysLater = calendar.date(byAdding: .day, value: 14, to: now) else { return 0 }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone
        let fourteenDaysLaterStr = fmt.string(from: fourteenDaysLater)

        return allRecurringStreams.reduce(0.0) { sum, stream in
            guard let nextDateStr = stream.predictedNextDate else { return sum }
            if nextDateStr >= todayStr && nextDateStr <= fourteenDaysLaterStr {
                return sum + stream.averageAmount
            }
            return sum
        }
    }

    /// Most-recent spend date per merchant over the last `lookbackDays`.
    /// Keyed by lowercased, whitespace-trimmed merchant name.
    func fetchRecentExpenseMerchantDates(lookbackDays: Int = 45) async -> [String: String] {
        let cal = Calendar.bablo
        guard let start = cal.date(byAdding: .day, value: -lookbackDays, to: Date()) else { return [:] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = cal.timeZone

        struct MerchantDateRow: Codable {
            let merchantName: String?
            let spendDate: String?
            enum CodingKeys: String, CodingKey {
                case merchantName = "merchant_name"
                case spendDate = "spend_date"
            }
        }

        do {
            let rows: [MerchantDateRow] = try await supabase
                .from("transactions")
                .select("merchant_name, spend_date")
                .gte("spend_date", value: fmt.string(from: start))
                .gt("amount", value: 0)
                .eq("is_spend", value: true)
                .order("spend_date", ascending: false)
                .limit(500)
                .execute()
                .value

            var latestByMerchant: [String: String] = [:]
            for row in rows {
                guard let rawMerchant = row.merchantName,
                      let spendDate = row.spendDate else { continue }
                let key = rawMerchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                if latestByMerchant[key] == nil {
                    latestByMerchant[key] = spendDate
                }
            }
            return latestByMerchant
        } catch {
            Logger.e("SubscriptionsService: Failed to fetch recent expense merchant dates: \(error)")
            return [:]
        }
    }

    // MARK: - Manual stream management

    func createManualStream(transactionId: Int, frequency: String) async throws {
        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetService.BudgetError.noUser
        }

        Logger.d("SubscriptionsService: Creating manual stream for transaction \(transactionId)")

        let body: [String: Any] = [
            "transaction_id": transactionId,
            "frequency": frequency,
            "user_id": userId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        try await supabase.functions.invoke(
            "create-manual-stream",
            options: FunctionInvokeOptions(body: bodyData)
        )

        Logger.i("SubscriptionsService: Manual stream created successfully")
        try await fetchSubscriptions()
    }

    func deleteManualStream(streamId: Int) async throws {
        Logger.d("SubscriptionsService: Deleting manual stream \(streamId)")

        try await supabase
            .from("recurring_streams_table")
            .delete()
            .eq("id", value: streamId)
            .eq("is_manual", value: true)
            .execute()

        Logger.i("SubscriptionsService: Manual stream deleted")
        try await fetchSubscriptions()
    }

    /// Trigger recurring transaction sync from Plaid
    func syncRecurringTransactions() async throws {
        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetService.BudgetError.noUser
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        struct ItemID: Codable { let plaid_item_id: String }
        let items: [ItemID] = try await supabase
            .from("items_table")
            .select("plaid_item_id")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value

        guard let firstItem = items.first else {
            Logger.w("SubscriptionsService: No active items found for recurring sync")
            return
        }

        let body = [
            "plaid_item_id": firstItem.plaid_item_id,
            "user_id": userId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        try await supabase.functions.invoke(
            "sync-recurring-transactions",
            options: FunctionInvokeOptions(body: bodyData)
        )

        Logger.i("SubscriptionsService: Recurring transaction sync triggered successfully")

        // Refresh data
        try await fetchSubscriptions()
        await scanIdleSubscriptions()
    }
}
