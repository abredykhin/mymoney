//
//  CoachService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 3
//  Handles AI Coach Insights via Supabase Edge Functions
//

import Foundation
import Supabase

// MARK: - Data Models

struct CoachInsight: Codable, Equatable {
    let badge: String
    let headline: String
    let nudgeText: String
    let actionLabel: String
    let alternativeTip: String

    enum CodingKeys: String, CodingKey {
        case badge
        case headline
        case nudgeText = "nudge_text"
        case actionLabel = "action_label"
        case alternativeTip = "alternative_tip"
    }
}

// MARK: - Service

@MainActor
class CoachService: ObservableObject {
    @Published var currentInsight: CoachInsight? = nil
    @Published var isDismissed: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    /// Minimum spacing between non-forced network refreshes. The edge function enforces
    /// the same 24h cooldown server-side; this client guard stops redundant invokes when
    /// Home re-renders or its id-keyed load task re-runs in quick succession (which was
    /// causing the card to regenerate a couple of times right after launch).
    private static let refreshCooldown: TimeInterval = 24 * 60 * 60
    private var lastFetchedAt: Date?
    /// Coalesces overlapping callers onto a single in-flight request.
    private var inFlightTask: Task<CoachInsight, Error>?

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetch tailored financial recommendations and manga nudge insights
    func fetchCoachInsights(force: Bool = false) async throws -> CoachInsight {
        // Coalesce concurrent callers onto the same request instead of firing several.
        if let inFlight = inFlightTask {
            return try await inFlight.value
        }

        // Skip the round-trip entirely if we already refreshed within the cooldown
        // window (non-forced calls only — the Coach tab's manual refresh passes force).
        if !force,
           let last = lastFetchedAt,
           let cached = currentInsight,
           Date().timeIntervalSince(last) < Self.refreshCooldown {
            Logger.d("CoachService: Skipping fetch; within 24h refresh cooldown")
            return cached
        }

        Logger.d("CoachService: Invoking gemini-coach-insights function (force: \(force))")

        let task = Task { [supabase] () throws -> CoachInsight in
            let body: [String: Any] = ["force": force]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            return try await supabase.functions.invoke(
                "gemini-coach-insights",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: bodyData
                )
            )
        }
        inFlightTask = task
        isLoading = true
        error = nil
        defer {
            isLoading = false
            inFlightTask = nil
        }

        do {
            let insight = try await task.value
            self.currentInsight = insight
            self.isDismissed = false
            self.lastFetchedAt = Date()
            Logger.i("CoachService: Loaded Coach insights successfully")
            return insight
        } catch {
            Logger.e("CoachService: Failed to fetch Coach insights: \(error)")
            self.error = error
            throw error
        }
    }

    /// Dismiss the current insight
    func dismissInsight() {
        self.isDismissed = true
    }
}
