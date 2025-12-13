//
//  SupabaseManager.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 2
//

import Foundation
import Supabase

/// Manages the Supabase client instance and configuration
class SupabaseManager {
    static let shared = SupabaseManager()

    /// The Supabase client instance
    /// Make sure to configure SUPABASE_URL and SUPABASE_ANON_KEY in your project settings
    let client: SupabaseClient

    private init() {
        // Read configuration from Info.plist or environment
        let supabaseURL = "https://teuyzmreoyganejfvquk.supabase.co"
        let supabaseAnonKey = "sb_publishable_7ZUYuwTGQ-MaL0l-d7B6DQ_09GHiOLl"

        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid SUPABASE_URL format")
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )

        Logger.i("SupabaseManager: Initialized with URL: \(supabaseURL)")
    }

    /// Get the current authenticated user session
    var currentSession: Session? {
        get async {
            do {
                return try await client.auth.session
            } catch {
                Logger.e("SupabaseManager: Failed to get session: \(error)")
                return nil
            }
        }
    }

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        get async {
            await currentSession != nil
        }
    }
}
