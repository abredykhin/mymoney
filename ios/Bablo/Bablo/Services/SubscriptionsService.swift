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

            let (subs, all) = try await (fetchSubs, fetchAllStreams)
            self.subscriptions = subs
            self.allRecurringStreams = all
            Logger.i("SubscriptionsService: Loaded \(subs.count) active subscriptions and \(all.count) active recurring streams")
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
