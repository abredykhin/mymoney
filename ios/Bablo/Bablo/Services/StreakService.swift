//
//  StreakService.swift
//  Bablo
//

import Foundation
import Supabase

@MainActor
class StreakService: ObservableObject {
    @Published var userStreak: UserStreak? = nil
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Dynamic user streak fetch
    func fetchUserStreak() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let streak: [UserStreak] = try await supabase
                .rpc("get_user_spending_streak")
                .execute()
                .value
            
            self.userStreak = streak.first
            Logger.i("StreakService: Loaded streak tracker successfully: \(self.userStreak?.currentStreak ?? 0) days")
        } catch {
            Logger.e("StreakService: Failed to fetch user spending streak: \(error)")
            self.error = error
            throw error
        }
    }
}
