//
//  TransactionsService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 4
//  Replaces: Model/TransactionsService.swift (legacy OpenAPI client)
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Data Models

/// Represents a financial transaction
struct Transaction: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let account_id: Int // Keep snake_case for compatibility
    let amount: Double
    let date: String
    let authorized_date: String? // Authorized date
    let name: String
    let merchant_name: String? // Keep snake_case for compatibility
    let pending: Bool
    let category: [String]?
    let transaction_id: String // Keep snake_case for compatibility
    let pending_transaction_transaction_id: String? // For compatibility with old code
    let iso_currency_code: String? // Currency code
    let payment_channel: String? // Payment channel (online, in store, etc.)
    let user_id: String? // User ID (UUID string from Supabase auth)
    let logo_url: String? // Merchant logo URL
    let website: String? // Merchant website
    let personal_finance_category: String? // Personal finance category
    let personal_finance_subcategory: String? // Personal finance subcategory
    let created_at: String? // Created timestamp
    let updated_at: String? // Updated timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case account_id
        case amount
        case date
        case authorized_date
        case name
        case merchant_name
        case pending
        case category
        case transaction_id
        case pending_transaction_transaction_id
        case iso_currency_code
        case payment_channel
        case user_id
        case logo_url
        case website
        case personal_finance_category
        case personal_finance_subcategory
        case created_at
        case updated_at
    }

    // Computed properties for camelCase access (if needed)
    var accountId: Int { account_id }
    var merchantName: String? { merchant_name }
    var transactionId: String { transaction_id }
    var isoCurrencyCode: String? { iso_currency_code }
    var paymentChannel: String? { payment_channel }
    var userId: String? { user_id }
    var logoUrl: String? { logo_url }
    var personalFinanceCategory: String? { personal_finance_category }
    var personalFinanceSubcategory: String? { personal_finance_subcategory }

    var displayName: String {
        merchant_name ?? name
    }

    var primaryCategory: String? {
        category?.first
    }

    var isExpense: Bool {
        amount > 0
    }

    var absoluteAmount: Double {
        abs(amount)
    }

    /// Determines if this transaction is a transfer between accounts
    /// Transfers should be excluded from income/expense calculations
    var isTransfer: Bool {
        // Check if personal_finance_category indicates a transfer
        if let category = personal_finance_category?.uppercased() {
            return category.contains("TRANSFER")
        }
        // Fallback: check if name contains "Payment" or "Transfer" explicitly
        let name = self.name.uppercased()
        return name.contains("PAYMENT") || name.contains("TRANSFER")
    }
}

/// Pagination metadata
struct PaginationInfo: Equatable {
    let totalCount: Int
    let limit: Int
    let hasMore: Bool
    let nextOffset: Int?
}

/// Filter criteria for transactions
struct TransactionFilter: Equatable {
    var category: String?
    var startDate: String?
    var endDate: String?
    var search: String?

    var isEmpty: Bool {
        category == nil && startDate == nil && endDate == nil && search == nil
    }

    init(category: String? = nil, startDate: String? = nil, endDate: String? = nil, search: String? = nil) {
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.search = search
    }
}

/// Fetch options for transaction queries
struct FetchOptions {
    let limit: Int
    let offset: Int
    let filter: TransactionFilter
    let forceRefresh: Bool

    init(
        limit: Int = 50,
        offset: Int = 0,
        filter: TransactionFilter = TransactionFilter(),
        forceRefresh: Bool = false
    ) {
        self.limit = limit
        self.offset = offset
        self.filter = filter
        self.forceRefresh = forceRefresh
    }
}

// MARK: - Service

/// Service for managing transactions via Supabase direct database access
@MainActor
class TransactionsService: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var paginationInfo: PaginationInfo?
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client
    private var currentOffset: Int = 0

    // MARK: - Public Methods

    /// Fetch transactions with filters and pagination
    /// - Parameters:
    ///   - options: Fetch options including limit, offset, and filters
    ///   - loadMore: If true, appends to existing transactions; otherwise replaces
    func fetchTransactions(options: FetchOptions = FetchOptions(), loadMore: Bool = false) async throws {
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        Logger.d("TransactionsService: Fetching transactions (offset: \(options.offset), limit: \(options.limit))")

        do {
            var query = supabase
                .from("transactions_table")
                .select(count: .exact)

            // Apply filters before ordering and ranging
            if let category = options.filter.category {
                query = query.contains("category", value: [category])
            }

            if let startDate = options.filter.startDate {
                query = query.gte("date", value: startDate)
            }

            if let endDate = options.filter.endDate {
                query = query.lte("date", value: endDate)
            }

            if let search = options.filter.search, !search.isEmpty {
                query = query.or("name.ilike.%\(search)%,merchant_name.ilike.%\(search)%")
            }

            // Apply ordering and pagination, then execute
            let response: [Transaction] = try await query
                .order("date", ascending: false)
                .order("id", ascending: false)
                .range(from: options.offset, to: options.offset + options.limit - 1)
                .execute().value

            Logger.i("TransactionsService: Received \(response.count) transactions")

            // Get total count from response headers
            let totalCount = response.count // Note: Supabase returns count in headers

            if loadMore {
                self.transactions.append(contentsOf: response)
            } else {
                self.transactions = response
            }

            // Update pagination info
            let hasMore = response.count == options.limit
            let nextOffset = hasMore ? options.offset + options.limit : nil

            self.paginationInfo = PaginationInfo(
                totalCount: totalCount,
                limit: options.limit,
                hasMore: hasMore,
                nextOffset: nextOffset
            )

            self.currentOffset = options.offset + response.count

            Logger.i("TransactionsService: Successfully loaded transactions (hasMore: \(hasMore))")
        } catch {
            Logger.e("TransactionsService: Failed to fetch transactions: \(error)")
            self.error = error
            throw error
        }
    }

    /// Fetch recent transactions (last 50)
    /// - Parameters:
    ///   - forceRefresh: Force refresh even if cache is recent
    ///   - loadMore: If true, appends to existing transactions
    ///   - limit: Number of transactions to fetch
    func fetchRecentTransactions(forceRefresh: Bool = false, loadMore: Bool = false, limit: Int = 50) async throws {
        Logger.d("TransactionsService: Fetching recent transactions (limit: \(limit), loadMore: \(loadMore))")

        let offset = loadMore ? transactions.count : 0
        let options = FetchOptions(limit: limit, offset: offset, forceRefresh: forceRefresh)

        try await fetchTransactions(options: options, loadMore: loadMore)
    }

    /// Fetch transactions for a specific account
    /// - Parameter accountId: Account ID
    func fetchTransactionsForAccount(accountId: Int, options: FetchOptions = FetchOptions()) async throws {
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        Logger.d("TransactionsService: Fetching transactions for account \(accountId)")

        do {
            var query = supabase
                .from("transactions_table")
                .select()
                .eq("account_id", value: accountId)

            // Apply additional filters before ordering
            if let startDate = options.filter.startDate {
                query = query.gte("date", value: startDate)
            }

            if let endDate = options.filter.endDate {
                query = query.lte("date", value: endDate)
            }

            // Apply ordering and pagination, then execute
            let response: [Transaction] = try await query
                .order("date", ascending: false)
                .order("id", ascending: false)
                .range(from: options.offset, to: options.offset + options.limit - 1)
                .execute().value

            Logger.i("TransactionsService: Received \(response.count) transactions for account \(accountId)")

            self.transactions = response

            let hasMore = response.count == options.limit
            self.paginationInfo = PaginationInfo(
                totalCount: response.count,
                limit: options.limit,
                hasMore: hasMore,
                nextOffset: hasMore ? options.offset + options.limit : nil
            )
        } catch {
            Logger.e("TransactionsService: Failed to fetch transactions for account: \(error)")
            self.error = error
            throw error
        }
    }

    /// Load more transactions (pagination)
    func loadMore(filter: TransactionFilter = TransactionFilter()) async throws {
        guard let nextOffset = paginationInfo?.nextOffset else {
            Logger.d("TransactionsService: No more transactions to load")
            return
        }

        Logger.d("TransactionsService: Loading more transactions (offset: \(nextOffset))")

        let options = FetchOptions(
            limit: paginationInfo?.limit ?? 50,
            offset: nextOffset,
            filter: filter
        )

        try await fetchTransactions(options: options, loadMore: true)
    }

    /// Get spending by category for a date range
    /// - Parameters:
    ///   - startDate: Start date (YYYY-MM-DD)
    ///   - endDate: End date (YYYY-MM-DD)
    /// - Returns: Dictionary of category to total spending
    func getSpendingByCategory(startDate: String, endDate: String) async throws -> [String: Double] {
        Logger.d("TransactionsService: Fetching spending by category (\(startDate) to \(endDate))")

        do {
            let transactions: [Transaction] = try await supabase
                .from("transactions_table")
                .select()
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .gt("amount", value: 0) // Only expenses
                .execute()
                .value

            Logger.i("TransactionsService: Received \(transactions.count) transactions for category breakdown")

            // Group by primary category
            var categoryTotals: [String: Double] = [:]
            for transaction in transactions {
                let category = transaction.primaryCategory ?? "Uncategorized"
                categoryTotals[category, default: 0] += transaction.absoluteAmount
            }

            return categoryTotals
        } catch {
            Logger.e("TransactionsService: Failed to fetch spending by category: \(error)")
            throw error
        }
    }

    /// Clear cached transactions
    func clearCache() {
        transactions = []
        paginationInfo = nil
        currentOffset = 0
        Logger.d("TransactionsService: Cleared cache")
    }
}

// MARK: - Helper Extensions

extension Transaction {
    /// Format date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        if let date = formatter.date(from: date) {
            formatter.dateFormat = "MMM d, yyyy"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date)
        }

        return date
    }

    /// Format amount for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: absoluteAmount)) ?? "$0.00"
    }
}

// MARK: - Stats Models

struct MonthlyTransactionStats: Decodable {
    let year: Double
    let month: Double
    let total_in: Double
    let total_out: Double
    
    var totalIn: Double { total_in }
    var totalOut: Double { total_out }
}

struct DailyTransactionStats: Decodable {
    let date: String
    let total_in: Double
    let total_out: Double
    
    var totalIn: Double { total_in }
    var totalOut: Double { total_out }
}

// MARK: - Stats Extensions for TransactionsService

extension TransactionsService {
    /// Fetch monthly statistics for a date range
    func fetchMonthlyStats(startDate: String, endDate: String) async throws -> [MonthlyTransactionStats] {
        Logger.d("TransactionsService: Fetching monthly stats")
        
        struct Params: Encodable {
            let start_date: String
            let end_date: String
        }
        
        let params = Params(start_date: startDate, end_date: endDate)
        
        do {
            let stats: [MonthlyTransactionStats] = try await supabase
                .rpc("get_monthly_transaction_stats", params: params)
                .execute()
                .value
            
            return stats
        } catch {
            Logger.e("TransactionsService: Failed to fetch monthly stats: \(error)")
            // Provide empty fallback or rethrow - here we rethrow to let UI handle it
            throw error
        }
    }
    
    /// Fetch daily statistics for a date range
    func fetchDailyStats(startDate: String, endDate: String) async throws -> [DailyTransactionStats] {
        Logger.d("TransactionsService: Fetching daily stats")
        
        struct Params: Encodable {
            let start_date: String
            let end_date: String
        }
        
        let params = Params(start_date: startDate, end_date: endDate)
        
        do {
            let stats: [DailyTransactionStats] = try await supabase
                .rpc("get_daily_transaction_stats", params: params)
                .execute()
                .value
            
            return stats
        } catch {
            Logger.e("TransactionsService: Failed to fetch daily stats: \(error)")
            throw error
        }
    }
}
