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
}
