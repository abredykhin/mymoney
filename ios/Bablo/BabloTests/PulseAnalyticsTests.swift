//
//  PulseAnalyticsTests.swift
//  BabloTests
//

import Testing
import Foundation
import Supabase
@testable import Bablo

struct PulseAnalyticsTests {

    @Test @MainActor func testLivePulseWeeklyEnergy() async throws {
        guard await TestSupabaseClient.isAvailable() else { return }
        // 1. Initialize client using the persistent local Supabase stack
        let client = TestSupabaseClient.shared
        
        // 2. Authenticate as the seeded user test@example.com to clear RLS
        _ = try await client.auth.signIn(email: "test@example.com", password: "password")
        
        // 3. Initialize the service with the live local client
        let service = PulseService(supabaseClient: client)
        
        // 4. Fetch daily weekly energy from live PostgreSQL aggregates
        await service.fetchDailyEnergy(startDate: "2026-01-20", endDate: "2026-01-27")
        
        // 5. Assert live database response matches the contract
        #expect(service.dailyEnergy.count == 8)
        let peakDay = service.dailyEnergy.first(where: { $0.isPeak })
        #expect(peakDay != nil)
        #expect(peakDay?.weekday == "Sat")
        #expect(peakDay?.peakMerchant == "European Market Deli & Cafe")
        #expect(peakDay?.totalSpent == 434.78)
        #expect(peakDay?.peakAmount == 218.4)
    }
    
    @Test @MainActor func testLivePulseTopMerchants() async throws {
        guard await TestSupabaseClient.isAvailable() else { return }
        // 1. Initialize client using the persistent local Supabase stack
        let client = TestSupabaseClient.shared
        
        // 2. Authenticate as the seeded user test@example.com to clear RLS
        _ = try await client.auth.signIn(email: "test@example.com", password: "password")
        
        // 3. Initialize the service with the live local client
        let service = PulseService(supabaseClient: client)
        
        // 4. Fetch top merchants from live PostgreSQL aggregates
        await service.fetchTopMerchants(startDate: "2026-01-01", endDate: "2026-01-27", limit: 5)
        
        // 5. Assert live database response matches the contract
        let top = try #require(service.topMerchants.first, "Expected at least one merchant from DB")
        #expect(service.topMerchants.count == 5)
        #expect(top.merchantName == "Romanov Law")
        #expect(top.totalSpent == 5000)
        #expect(top.transactionCount == 1)
    }
}
