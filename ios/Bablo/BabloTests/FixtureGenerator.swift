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
        print("FixtureGenerator: Successfully generated accounts.json contract fixture at: \(accountsPath.path)")
    }
}
