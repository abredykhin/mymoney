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
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetch tailored financial recommendations and manga nudge insights
    func fetchCoachInsights() async throws -> CoachInsight {
        isLoading = true
        error = nil
        defer { isLoading = false }

        Logger.d("CoachService: Invoking gemini-coach-insights function")

        do {
            let insight: CoachInsight = try await supabase.functions.invoke(
                "gemini-coach-insights",
                options: FunctionInvokeOptions(
                    method: .post
                )
            )
            self.currentInsight = insight
            Logger.i("CoachService: Loaded Coach insights successfully")
            return insight
        } catch {
            Logger.e("CoachService: Failed to fetch Coach insights: \(error)")
            self.error = error
            throw error
        }
    }
}
