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
    let plaid_item_id: String?
    let item_status: String
    let plaid_health_updated_at: Date?
    let plaid_last_error_code: String?
    let plaid_last_error_message: String?
    let plaid_access_expires_at: Date?
    var accounts: [BankAccount]

    enum CodingKeys: String, CodingKey {
        case id
        case bank_name
        case logo
        case primary_color
        case url
        case plaid_item_id
        case item_status
        case plaid_health_updated_at
        case plaid_last_error_code
        case plaid_last_error_message
        case plaid_access_expires_at
        case accounts
    }

    init(
        id: Int,
        bank_name: String,
        logo: String?,
        primary_color: String?,
        url: String?,
        plaid_item_id: String? = nil,
        item_status: String = "good",
        plaid_health_updated_at: Date? = nil,
        plaid_last_error_code: String? = nil,
        plaid_last_error_message: String? = nil,
        plaid_access_expires_at: Date? = nil,
        accounts: [BankAccount]
    ) {
        self.id = id
        self.bank_name = bank_name
        self.logo = logo
        self.primary_color = primary_color
        self.url = url
        self.plaid_item_id = plaid_item_id
        self.item_status = item_status
        self.plaid_health_updated_at = plaid_health_updated_at
        self.plaid_last_error_code = plaid_last_error_code
        self.plaid_last_error_message = plaid_last_error_message
        self.plaid_access_expires_at = plaid_access_expires_at
        self.accounts = accounts
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

    var healthStatus: PlaidItemHealthStatus {
        PlaidItemHealthStatus(rawValue: item_status.lowercased()) ?? .good
    }

    var needsAttention: Bool {
        healthStatus != .good
    }

    var repairable: Bool {
        healthStatus.isRepairable
    }
}

enum PlaidItemHealthStatus: String, Codable, Equatable, Hashable {
    case good
    case needsReauth = "needs_reauth"
    case pendingDisconnect = "pending_disconnect"
    case pendingExpiration = "pending_expiration"
    case permissionRevoked = "permission_revoked"
    case newAccountsAvailable = "new_accounts_available"

    var displayTitle: String {
        switch self {
        case .good:
            return "Connected"
        case .needsReauth:
            return "Needs refresh"
        case .pendingDisconnect, .pendingExpiration:
            return "Refresh soon"
        case .permissionRevoked:
            return "Access revoked"
        case .newAccountsAvailable:
            return "New accounts"
        }
    }

    var displayMessage: String {
        switch self {
        case .good:
            return "Connection is healthy."
        case .needsReauth:
            return "Refresh this bank connection to keep transactions syncing."
        case .pendingDisconnect:
            return "Plaid says this connection may disconnect soon."
        case .pendingExpiration:
            return "Plaid says this connection consent expires soon."
        case .permissionRevoked:
            return "Access was revoked. Try repairing, or link this bank again if Plaid asks."
        case .newAccountsAvailable:
            return "This bank has additional accounts available to share."
        }
    }

    var isRepairable: Bool {
        switch self {
        case .good:
            return false
        case .needsReauth, .pendingDisconnect, .pendingExpiration, .permissionRevoked, .newAccountsAvailable:
            return true
        }
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
    var hidden: Bool
    let iso_currency_code: String? // For compatibility
    let updated_at: Date? // For compatibility
    let plaid_access_revoked_at: Date?

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
        case plaid_access_revoked_at
    }

    init(
        id: Int,
        item_id: Int,
        name: String,
        mask: String?,
        official_name: String?,
        current_balance: Double,
        available_balance: Double?,
        _type: String,
        subtype: String?,
        hidden: Bool,
        iso_currency_code: String?,
        updated_at: Date?,
        plaid_access_revoked_at: Date? = nil
    ) {
        self.id = id
        self.item_id = item_id
        self.name = name
        self.mask = mask
        self.official_name = official_name
        self.current_balance = current_balance
        self.available_balance = available_balance
        self._type = _type
        self.subtype = subtype
        self.hidden = hidden
        self.iso_currency_code = iso_currency_code
        self.updated_at = updated_at
        self.plaid_access_revoked_at = plaid_access_revoked_at
    }

    // Convenience properties for camelCase access
    var itemId: Int { item_id }
    var officialName: String? { official_name }
    var currentBalance: Double { current_balance }
    var availableBalance: Double? { available_balance }
    var type: String { _type }
    var accessRevoked: Bool { plaid_access_revoked_at != nil }

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
            // Fetch all accounts. Visibility is applied by presentation helpers, not this base model.
            let response: [AccountWithBank] = try await supabase
                .from("accounts_with_banks")
                .select()
                .order("name")
                .execute()
                .value

            Logger.i("AccountsService: Received \(response.count) accounts")

            // Group accounts by bank
            let groupedBanks = Dictionary(grouping: response) { $0.itemId }

            // Transform to Bank objects
            var banks: [Bank] = []
            for (itemId, accountsForBank) in groupedBanks {
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
                        iso_currency_code: accountData.isoCurrencyCode ?? "USD",
                        updated_at: accountData.updatedAt,
                        plaid_access_revoked_at: accountData.plaidAccessRevokedAt
                    )
                }

                let bank = Bank(
                    id: itemId,
                    bank_name: firstAccount.institutionName,
                    logo: firstAccount.institutionLogo,
                    primary_color: firstAccount.institutionColor,
                    url: firstAccount.institutionUrl,
                    plaid_item_id: firstAccount.plaidItemId,
                    item_status: firstAccount.itemStatus,
                    plaid_health_updated_at: firstAccount.plaidHealthUpdatedAt,
                    plaid_last_error_code: firstAccount.plaidLastErrorCode,
                    plaid_last_error_message: firstAccount.plaidLastErrorMessage,
                    plaid_access_expires_at: firstAccount.plaidAccessExpiresAt,
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
                banksWithAccounts[bankIndex].accounts[accountIndex].hidden = hidden
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
        visibleBanksWithAccounts
            .flatMap { $0.accounts }
            .reduce(0) { $0 + $1.current_balance }
    }

    /// Banks with only accounts that are visible in spend/budget surfaces.
    var visibleBanksWithAccounts: [Bank] {
        banksWithAccounts.compactMap { bank in
            let visibleAccounts = bank.accounts.filter { !$0.hidden && !$0.accessRevoked }
            guard !visibleAccounts.isEmpty else { return nil }

            var visibleBank = bank
            visibleBank.accounts = visibleAccounts
            return visibleBank
        }
    }

    /// Clear user-scoped account data when the authenticated user changes.
    func clearCache() {
        banksWithAccounts = []
        lastUpdated = nil
        error = nil
        cacheManager.clearCache()
        Logger.d("AccountsService: Cleared cache")
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
    let accountId: String?
    let isoCurrencyCode: String?
    let updatedAt: Date?
    let institutionId: Int
    let institutionName: String
    let institutionLogo: String?
    let institutionColor: String?
    let institutionUrl: String?
    let plaidItemId: String?
    let itemStatus: String
    let plaidHealthUpdatedAt: Date?
    let plaidLastErrorCode: String?
    let plaidLastErrorMessage: String?
    let plaidAccessExpiresAt: Date?
    let plaidAccessRevokedAt: Date?

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
        case accountId = "account_id"
        case isoCurrencyCode = "iso_currency_code"
        case updatedAt = "updated_at"
        case institutionId = "institution_id"
        case institutionName = "institution_name"
        case institutionLogo = "institution_logo"
        case institutionColor = "institution_color"
        case institutionUrl = "institution_url"
        case plaidItemId = "plaid_item_id"
        case itemStatus = "item_status"
        case plaidHealthUpdatedAt = "plaid_health_updated_at"
        case plaidLastErrorCode = "plaid_last_error_code"
        case plaidLastErrorMessage = "plaid_last_error_message"
        case plaidAccessExpiresAt = "plaid_access_expires_at"
        case plaidAccessRevokedAt = "plaid_access_revoked_at"
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
