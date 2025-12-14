//
//  AccountsService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 4
//  Replaces: Model/BankAccountsService.swift (legacy OpenAPI client)
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Data Models

/// Represents a bank with its accounts
struct Bank: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let bank_name: String // Keep old property name for compatibility
    let logo: String?
    let primary_color: String? // Keep snake_case for compatibility
    let url: String?
    var accounts: [BankAccount]

    enum CodingKeys: String, CodingKey {
        case id
        case bank_name
        case logo
        case primary_color
        case url
        case accounts
    }

    // Convenience property for camelCase access
    var name: String { bank_name }

    // Computed property for decoded logo (base64 to UIImage)
    var decodedLogo: UIImage? {
        guard let logo = logo,
              logo.hasPrefix("data:image") else {
            return nil
        }

        // Extract base64 part from data URL
        let components = logo.components(separatedBy: ",")
        guard components.count == 2,
              let base64String = components.last,
              let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    // Convenience property for SwiftUI Color
    var primaryColor: Color? {
        guard let colorHex = primary_color else { return nil }
        return Color(hex: colorHex)
    }
}

/// Represents a bank account
struct BankAccount: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let item_id: Int // Keep snake_case for compatibility
    let name: String
    let mask: String?
    let official_name: String? // Keep snake_case for compatibility
    let current_balance: Double // Keep snake_case for compatibility
    let available_balance: Double? // Keep snake_case for compatibility
    let _type: String // Underscore prefix for compatibility with old schema
    let subtype: String?
    let hidden: Bool
    let iso_currency_code: String? // For compatibility
    let updated_at: Date? // For compatibility

    enum CodingKeys: String, CodingKey {
        case id
        case item_id
        case name
        case mask
        case official_name
        case current_balance
        case available_balance
        case _type = "type"
        case subtype
        case hidden
        case iso_currency_code
        case updated_at
    }

    // Convenience properties for camelCase access
    var itemId: Int { item_id }
    var officialName: String? { official_name }
    var currentBalance: Double { current_balance }
    var availableBalance: Double? { available_balance }
    var type: String { _type }

    var displayName: String {
        official_name ?? name
    }

    var maskedNumber: String {
        mask.map { "••••\($0)" } ?? ""
    }
}

// MARK: - Service

/// Service for managing bank accounts via Supabase direct database access
@MainActor
class AccountsService: ObservableObject {
    @Published var banksWithAccounts: [Bank] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client
    private let cacheManager = AccountCacheManager()

    init() {
        loadCachedData()
    }

    // MARK: - Public Methods

    /// Refresh accounts from Supabase database
    /// - Parameter forceRefresh: Force refresh even if cache is recent
    func refreshAccounts(forceRefresh: Bool = false) async throws {
        // Use cache if recent (within 5 minutes)
        if !forceRefresh,
           !banksWithAccounts.isEmpty,
           let lastUpdate = lastUpdated,
           Date().timeIntervalSince(lastUpdate) < 300 {
            Logger.i("AccountsService: Using cached data (updated \(Int(Date().timeIntervalSince(lastUpdate)))s ago)")
            return
        }

        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        Logger.d("AccountsService: Fetching accounts from Supabase")

        do {
            // Fetch accounts with bank information using a view or join
            // The accounts view in Supabase joins accounts with items and institutions
            let response: [AccountWithBank] = try await supabase
                .from("accounts_with_banks")
                .select()
                .eq("hidden", value: false)
                .order("name")
                .execute()
                .value

            Logger.i("AccountsService: Received \(response.count) accounts")

            // Group accounts by bank
            let groupedBanks = Dictionary(grouping: response) { $0.institutionId }

            // Transform to Bank objects
            var banks: [Bank] = []
            for (institutionId, accountsForBank) in groupedBanks {
                guard let firstAccount = accountsForBank.first else { continue }

                let bankAccounts = accountsForBank.map { accountData in
                    BankAccount(
                        id: accountData.id,
                        item_id: accountData.itemId,
                        name: accountData.name,
                        mask: accountData.mask,
                        official_name: accountData.officialName,
                        current_balance: accountData.currentBalance,
                        available_balance: accountData.availableBalance,
                        _type: accountData.type,
                        subtype: accountData.subtype,
                        hidden: accountData.hidden,
                        iso_currency_code: "USD", // Default to USD
                        updated_at: Date() // Current timestamp
                    )
                }

                let bank = Bank(
                    id: institutionId,
                    bank_name: firstAccount.institutionName,
                    logo: firstAccount.institutionLogo,
                    primary_color: firstAccount.institutionColor,
                    url: firstAccount.institutionUrl,
                    accounts: bankAccounts
                )

                banks.append(bank)
            }

            // Sort banks by name
            banks.sort { $0.name < $1.name }

            self.banksWithAccounts = banks
            self.lastUpdated = Date()

            // Save to cache
            cacheManager.saveBanks(banks)

            Logger.i("AccountsService: Successfully loaded \(banks.count) banks")
        } catch {
            Logger.e("AccountsService: Failed to fetch accounts: \(error)")
            self.error = error
            throw error
        }
    }

    /// Toggle account visibility
    /// - Parameters:
    ///   - accountId: Account ID to update
    ///   - hidden: New hidden state
    func toggleAccountVisibility(accountId: Int, hidden: Bool) async throws {
        Logger.d("AccountsService: Toggling account \(accountId) visibility to \(hidden)")

        do {
            try await supabase
                .from("accounts")
                .update(["hidden": hidden])
                .eq("id", value: accountId)
                .execute()

            Logger.i("AccountsService: Successfully updated account visibility")

            // Update local state
            if let bankIndex = banksWithAccounts.firstIndex(where: { $0.accounts.contains(where: { $0.id == accountId }) }),
               let accountIndex = banksWithAccounts[bankIndex].accounts.firstIndex(where: { $0.id == accountId }) {
                let account = banksWithAccounts[bankIndex].accounts[accountIndex]
                banksWithAccounts[bankIndex].accounts[accountIndex] = BankAccount(
                    id: account.id,
                    item_id: account.item_id,
                    name: account.name,
                    mask: account.mask,
                    official_name: account.official_name,
                    current_balance: account.current_balance,
                    available_balance: account.available_balance,
                    _type: account._type,
                    subtype: account.subtype,
                    hidden: hidden,
                    iso_currency_code: account.iso_currency_code,
                    updated_at: account.updated_at
                )
            }

            // Refresh to get updated data
            try await refreshAccounts(forceRefresh: true)
        } catch {
            Logger.e("AccountsService: Failed to toggle account visibility: \(error)")
            throw error
        }
    }

    /// Get total balance across all visible accounts
    var totalBalance: Double {
        banksWithAccounts
            .flatMap { $0.accounts }
            .filter { !$0.hidden }
            .reduce(0) { $0 + $1.current_balance }
    }

    // MARK: - Private Methods

    private func loadCachedData() {
        let cachedBanks = cacheManager.fetchBanks()
        if !cachedBanks.isEmpty {
            self.banksWithAccounts = cachedBanks
            Logger.i("AccountsService: Loaded \(cachedBanks.count) banks from cache")
        }
    }
}

// MARK: - Database Models

/// Response model for accounts_with_banks view
private struct AccountWithBank: Codable {
    let id: Int
    let itemId: Int
    let name: String
    let mask: String?
    let officialName: String?
    let currentBalance: Double
    let availableBalance: Double?
    let type: String
    let subtype: String?
    let hidden: Bool
    let institutionId: Int
    let institutionName: String
    let institutionLogo: String?
    let institutionColor: String?
    let institutionUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case name
        case mask
        case officialName = "official_name"
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case type
        case subtype
        case hidden
        case institutionId = "institution_id"
        case institutionName = "institution_name"
        case institutionLogo = "institution_logo"
        case institutionColor = "institution_color"
        case institutionUrl = "institution_url"
    }
}

// MARK: - Cache Manager

/// Simple cache manager for accounts using UserDefaults
/// Note: For production, consider using CoreData or more robust caching
private class AccountCacheManager {
    private let cacheKey = "cached_banks_v2"

    func saveBanks(_ banks: [Bank]) {
        do {
            let data = try JSONEncoder().encode(banks)
            UserDefaults.standard.set(data, forKey: cacheKey)
            Logger.d("AccountCacheManager: Saved \(banks.count) banks to cache")
        } catch {
            Logger.e("AccountCacheManager: Failed to cache banks: \(error)")
        }
    }

    func fetchBanks() -> [Bank] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return []
        }

        do {
            let banks = try JSONDecoder().decode([Bank].self, from: data)
            return banks
        } catch {
            Logger.e("AccountCacheManager: Failed to decode cached banks: \(error)")
            return []
        }
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        Logger.d("AccountCacheManager: Cleared cache")
    }
}
