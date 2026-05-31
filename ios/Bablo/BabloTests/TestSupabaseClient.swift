//
//  TestSupabaseClient.swift
//  BabloTests
//

import Foundation
import Supabase

enum TestSupabaseClient {
    static let shared = SupabaseClient(
        supabaseURL: URL(string: "http://127.0.0.1:54321")!,
        supabaseKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
    )

    /// Returns true when the local Supabase dev stack is reachable.
    /// Call at the top of every live integration test:
    ///   `guard await TestSupabaseClient.isAvailable() else { return }`
    static func isAvailable() async -> Bool {
        let url = URL(string: "http://127.0.0.1:54321/health")!
        return (try? await URLSession.shared.data(from: url)) != nil
    }
}
