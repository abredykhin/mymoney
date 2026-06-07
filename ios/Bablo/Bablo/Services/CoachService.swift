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

    /// Coalesces overlapping callers onto a single in-flight request so simultaneous
    /// triggers (e.g. Home's load task re-running) don't fire duplicate invokes. The 24h
    /// refresh cadence itself is owned by the server: the edge function returns its cached
    /// insight within the cooldown window, so the client doesn't gate on time at all.
    private var inFlightTask: Task<CoachInsight, Error>?

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetch tailored financial recommendations and manga nudge insights
    func fetchCoachInsights(force: Bool = false) async throws -> CoachInsight {
        // Coalesce concurrent callers onto the same request instead of firing several.
        // The server decides whether to regenerate or return its cached insight (24h
        // cooldown), so the client always invokes and lets the backend drive the cadence.
        if let inFlight = inFlightTask {
            return try await inFlight.value
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
