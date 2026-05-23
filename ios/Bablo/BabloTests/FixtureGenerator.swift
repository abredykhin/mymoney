//
//  FixtureGenerator.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase

struct FixtureGenerator {
    
    // Set to 'true' to execute regeneration when running tests
    static let shouldRegenerate = false
    
    @Test func generateContracts() async throws {
        guard Self.shouldRegenerate else { return }
        
        let client = TestSupabaseClient.shared
        
        // Sign in to authentic local database session to clear Row Level Security (RLS)
        print("FixtureGenerator: Authenticating as test@example.com...")
        let _ = try await client.auth.signIn(email: "test@example.com", password: "password")
        
        // 1. Resolve local path of BabloTests/Fixtures directory
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturesDir = sourceFile.deletingLastPathComponent().appendingPathComponent("Fixtures")
        
        // Ensure directory exists
        try FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
        
        // 2. Query and save accounts list
        print("FixtureGenerator: Fetching accounts contract data...")
        let accountsResponse = try await client
            .from("accounts")
            .select("current_balance, type")
            .eq("hidden", value: false)
            .execute()
        
        let accountsPath = fixturesDir.appendingPathComponent("accounts.json")
        try accountsResponse.data.write(to: accountsPath)
        print("FixtureGenerator: Successfully generated accounts.json contract fixture")
        
        // 3. Query and save weekly energy RPC
        print("FixtureGenerator: Fetching weekly energy contract data...")
        struct EnergyParams: Encodable {
            let week_start: String
            let week_end: String
        }
        let energyResponse = try await client
            .rpc("get_pulse_weekly_energy", params: EnergyParams(week_start: "2026-01-20", week_end: "2026-01-27"))
            .execute()
            
        let energyPath = fixturesDir.appendingPathComponent("weekly_energy.json")
        try energyResponse.data.write(to: energyPath)
        print("FixtureGenerator: Successfully generated weekly_energy.json contract fixture")
        
        // 4. Query and save top merchants RPC
        print("FixtureGenerator: Fetching top merchants contract data...")
        struct MerchantParams: Encodable {
            let start_date: String
            let end_date: String
            let lim: Int
        }
        let merchantResponse = try await client
            .rpc("get_pulse_top_merchants", params: MerchantParams(start_date: "2026-01-01", end_date: "2026-01-27", lim: 5))
            .execute()
            
        let merchantPath = fixturesDir.appendingPathComponent("top_merchants.json")
        try merchantResponse.data.write(to: merchantPath)
        print("FixtureGenerator: Successfully generated top_merchants.json contract fixture")
    }
}
