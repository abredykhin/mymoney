//
//  TransactionsService.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/25/24.
//

import Foundation
import SwiftUI
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Data Structures

/// Represents pagination metadata for transaction lists
struct PaginationInfo: Equatable {
    let totalCount: Int
    let limit: Int
    let hasMore: Bool
    let nextCursor: String?
}

/// Filter criteria for transaction queries
struct TransactionFilter {
    var category: String?
    var startDate: String?
    var endDate: String?
    var search: String?
    
    var isEmpty: Bool {
        return category == nil && startDate == nil && endDate == nil && search == nil
    }
    
    init(category: String? = nil, startDate: String? = nil, endDate: String? = nil, search: String? = nil) {
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.search = search
    }
}

/// Common parameters for all transaction fetch operations
struct FetchOptions {
    let limit: Int
    let cursor: String?
    let filter: TransactionFilter
    let forceRefresh: Bool
    let loadMore: Bool
    
    init(
        limit: Int = 50,
        cursor: String? = nil,
        filter: TransactionFilter = TransactionFilter(),
        forceRefresh: Bool = false,
        loadMore: Bool = false
    ) {
        self.limit = limit
        self.cursor = cursor
        self.filter = filter
        self.forceRefresh = forceRefresh
        self.loadMore = loadMore
    }
}

/// Enum representing different transaction data sources
enum TransactionSource {
    case account(id: String)
    case item(id: String)
    case recent
    case all
    
    var description: String {
        switch self {
        case .account(let id):
            return "account \(id)"
        case .item(let id):
            return "item \(id)"
        case .recent:
            return "recent transactions"
        case .all:
            return "all transactions"
        }
    }
}

/// Result type for the transaction fetch operations
struct TransactionResult {
    let transactions: [Transaction]
    let pagination: PaginationInfo?
    let isFromCache: Bool
}

// MARK: - Constants

/// Cache time threshold in seconds
private let CACHE_VALIDITY_DURATION: TimeInterval = 300 // 5 minutes

// MARK: - TransactionsService
@MainActor
class TransactionsService: ObservableObject {
    // MARK: Published Properties
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var isUsingCachedData: Bool = false
    @Published var lastUpdated: Date?
    @Published var paginationInfo: PaginationInfo?
    @Published var hasNextPage: Bool = false
    
    // MARK: Private Properties
    private let transactionsManager = TransactionsManager()
    private var currentFilter = TransactionFilter()
    
    // MARK: - Public API Methods
    
    /// Fetches transactions for a specific account with optional pagination
    /// - Parameters:
    ///   - accountId: The account ID
    ///   - forceRefresh: Whether to force a refresh from the server
    ///   - loadMore: Whether to load the next page of transactions
    ///   - limit: Maximum number of transactions to fetch
    func fetchAccountTransactions(_ accountId: String, forceRefresh: Bool = false, loadMore: Bool = false, limit: Int = 50) async throws {
        if loadMore && !hasNextPage {
            Logger.i("No more pages to load")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let options = FetchOptions(
            limit: limit,
            cursor: loadMore ? paginationInfo?.nextCursor : nil,
            filter: currentFilter,
            forceRefresh: forceRefresh,
            loadMore: loadMore
        )
        
        let result = try await fetchTransactions(
            from: .account(id: accountId),
            options: options
        )
        
        updateState(from: result)
    }
    
    /// Fetches transactions for a specific item with optional pagination
    /// - Parameters:
    ///   - itemId: The item ID
    ///   - forceRefresh: Whether to force a refresh from the server
    ///   - loadMore: Whether to load the next page of transactions 
    ///   - limit: Maximum number of transactions to fetch
    func fetchItemTransactions(_ itemId: String, forceRefresh: Bool = false, loadMore: Bool = false, limit: Int = 50) async throws {
        if loadMore && !hasNextPage {
            Logger.i("No more pages to load")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let options = FetchOptions(
            limit: limit,
            cursor: loadMore ? paginationInfo?.nextCursor : nil,
            filter: currentFilter,
            forceRefresh: forceRefresh,
            loadMore: loadMore
        )
        
        let result = try await fetchTransactions(
            from: .item(id: itemId),
            options: options
        )
        
        updateState(from: result)
    }
    
    /// Fetches recent transactions with optional pagination
    /// - Parameters:
    ///   - forceRefresh: Whether to force a refresh from the server
    ///   - loadMore: Whether to load the next page of transactions
    ///   - limit: Maximum number of transactions to fetch
    func fetchRecentTransactions(forceRefresh: Bool = false, loadMore: Bool = false, limit: Int = 10) async throws {
        if loadMore && !hasNextPage {
            Logger.i("No more pages to load")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let options = FetchOptions(
            limit: limit,
            cursor: loadMore ? paginationInfo?.nextCursor : nil,
            filter: currentFilter,
            forceRefresh: forceRefresh,
            loadMore: loadMore
        )
        
        let result = try await fetchTransactions(
            from: .recent,
            options: options
        )
        
        updateState(from: result)
    }
    
    /// Method to fetch all transactions for the user with optional pagination
    /// - Parameters:
    ///   - forceRefresh: Whether to force a refresh from the server
    ///   - loadMore: Whether to load the next page of transactions
    ///   - limit: Maximum number of transactions to fetch
    func fetchAllTransactions(forceRefresh: Bool = false, loadMore: Bool = false, limit: Int = 50) async throws {
        // Reset pagination state for a new fetch
        if forceRefresh {
            resetPagination()
        }
        
        if loadMore && !hasNextPage {
            Logger.i("No more pages to load")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let options = FetchOptions(
            limit: limit,
            cursor: loadMore ? paginationInfo?.nextCursor : nil,
            filter: currentFilter,
            forceRefresh: forceRefresh,
            loadMore: loadMore
        )
        
        let result = try await fetchTransactions(
            from: .all,
            options: options
        )
        
        updateState(from: result)
    }
    
    // MARK: - State Management
    
    /// Resets pagination state
    func resetPagination() {
        paginationInfo = nil
        hasNextPage = false
    }
    
    /// Resets the entire service state
    func resetState() {
        transactions = []
        isLoading = false
        isUsingCachedData = false
        lastUpdated = nil
        resetPagination()
        clearFilters()
    }
    
    /// Sets filter criteria for subsequent transaction fetches
    /// - Parameters:
    ///   - category: Optional category filter
    ///   - startDate: Optional start date filter (YYYY-MM-DD)
    ///   - endDate: Optional end date filter (YYYY-MM-DD)
    ///   - search: Optional search term for transaction name/merchant name
    func setFilter(category: String? = nil, startDate: String? = nil, endDate: String? = nil, search: String? = nil) {
        currentFilter = TransactionFilter(category: category, startDate: startDate, endDate: endDate, search: search)
    }
    
    /// Clears all filter criteria
    func clearFilters() {
        currentFilter = TransactionFilter()
    }
    
    // MARK: - Private Methods
    
    /// Core method to fetch transactions with unified approach to caching, pagination, and error handling
    /// - Parameters:
    ///   - source: The source of transactions (account, item, recent, all)
    ///   - options: Options to control the fetch behavior including filters, pagination, etc.
    /// - Returns: A result containing fetched transactions and metadata
    private func fetchTransactions(from source: TransactionSource, options: FetchOptions) async throws -> TransactionResult {
        // Early cache check (if applicable)
        if shouldUseCache(options: options) {
            if let cachedResult = await loadFromCache(source: source, options: options) {
                return cachedResult
            }
        }
        
        // Get data from server
        return try await fetchFromServer(source: source, options: options)
    }
    
    /// Determines if we should try to use cached data
    /// - Parameter options: The fetch options
    /// - Returns: True if cache should be attempted
    private func shouldUseCache(options: FetchOptions) -> Bool {
        // Don't use cache if forcing refresh, loading more, or using cursor
        if options.forceRefresh || options.loadMore || options.cursor != nil {
            return false
        }
        
        // Don't use cache if filter is applied
        if !options.filter.isEmpty {
            return false
        }
        
        // Don't use cache if we don't have a valid cache timestamp
        if let lastUpdate = lastUpdated, Date().timeIntervalSince(lastUpdate) < CACHE_VALIDITY_DURATION {
            return true
        }
        
        return !transactions.isEmpty
    }
    
    /// Attempts to load data from the local cache
    /// - Parameters:
    ///   - source: The data source
    ///   - options: Fetch options
    /// - Returns: Optional transaction result if cache hit
    private func loadFromCache(source: TransactionSource, options: FetchOptions) async -> TransactionResult? {
        // Skip cache if filters are applied
        if !options.filter.isEmpty {
            return nil
        }
        
        var cachedTransactions: [Transaction] = []
        
        // Load from appropriate cache based on source
        switch source {
        case .account(let id):
            if let accountId = Int(id) {
                cachedTransactions = transactionsManager.fetchTransactions(for: accountId)
            }
        case .recent:
            cachedTransactions = transactionsManager.fetchRecentTransactions(limit: options.limit)
        case .item, .all:
            // For item and all, we typically don't have specialized cache
            return nil
        }
        
        // If we got cached data, return it
        if !cachedTransactions.isEmpty {
            Logger.i("Loaded \(cachedTransactions.count) transactions from cache for \(source.description)")
            
            // For load more operations, append to existing transactions
            let finalTransactions = options.loadMore ? 
                transactions + cachedTransactions : cachedTransactions
            
            // Determine if there may be more to load
            let hasMore = cachedTransactions.count >= options.limit
            
            return TransactionResult(
                transactions: finalTransactions,
                pagination: PaginationInfo(
                    totalCount: cachedTransactions.count, 
                    limit: options.limit, 
                    hasMore: hasMore, 
                    nextCursor: nil
                ),
                isFromCache: true
            )
        }
        
        return nil
    }
    
    /// Updates service state from a transaction result
    /// - Parameter result: The transaction result to apply
    private func updateState(from result: TransactionResult) {
        transactions = result.transactions
        isUsingCachedData = result.isFromCache
        paginationInfo = result.pagination
        hasNextPage = result.pagination?.hasMore ?? false
        
        if !result.isFromCache {
            lastUpdated = Date()
        }
    }
    
    /// Fetches transaction data from the server
    /// - Parameters:
    ///   - source: The data source
    ///   - options: Fetch options
    /// - Returns: Transaction result with fetched data
    private func fetchFromServer(source: TransactionSource, options: FetchOptions) async throws -> TransactionResult {
        guard let client = UserAccount.shared.client.map(\.self) else {
            Logger.e("Client is not set!")
            throw NSError(domain: "TransactionsService", code: 100, userInfo: [NSLocalizedDescriptionKey: "API client not available"])
        }
        
        // Log the request
        Logger.d("Fetching \(source.description) from server with options: \(String(describing: options))")
        
        // Process the request based on source
        switch source {
        case .account(let id):
            return try await fetchAccountTransactions(client: client, accountId: id, options: options)
            
        case .item(let id):
            return try await fetchItemTransactions(client: client, itemId: id, options: options)
            
        case .recent:
            return try await fetchRecentTransactionsFromServer(client: client, options: options)
            
        case .all:
            return try await fetchAllTransactionsFromServer(client: client, options: options)
        }
    }
    
    /// Fetches account transactions from the server
    private func fetchAccountTransactions(client: Client, accountId: String, options: FetchOptions) async throws -> TransactionResult {
        let source = TransactionSource.account(id: accountId)
        
        // Create query parameters
        var query = Operations.getAccountTransactions.Input.Query(accountId: accountId, limit: options.limit)
        applyFilterParameters(to: &query, from: options.filter)
        if let cursor = options.cursor {
            query.cursor = cursor
        }
        
        // Execute the request
        let response = try await client.getAccountTransactions(.init(query: query))
        
        // Process the response
        switch response {
        case .ok(let json):
            return extractTransactionData(from: json, source: source, options: options)
        case .unauthorized(_):
            handleUnauthorized()
            throw AuthenticationError.unauthorized
        default:
            throw APIError.unexpectedResponse(source: source.description)
        }
    }
    
    /// Fetches item transactions from the server
    private func fetchItemTransactions(client: Client, itemId: String, options: FetchOptions) async throws -> TransactionResult {
        let source = TransactionSource.item(id: itemId)
        
        // Create query parameters
        var query = Operations.getItemTransactions.Input.Query(itemId: itemId, limit: options.limit)
        applyFilterParameters(to: &query, from: options.filter)
        if let cursor = options.cursor {
            query.cursor = cursor
        }
        
        // Execute the request
        let response = try await client.getItemTransactions(.init(query: query))
        
        // Process the response
        switch response {
        case .ok(let json):
            return extractTransactionData(from: json, source: source, options: options)
        case .unauthorized(_):
            handleUnauthorized()
            throw AuthenticationError.unauthorized
        default:
            throw APIError.unexpectedResponse(source: source.description)
        }
    }
    
    /// Fetches recent transactions from the server
    private func fetchRecentTransactionsFromServer(client: Client, options: FetchOptions) async throws -> TransactionResult {
        let source = TransactionSource.recent
        
        // Create query parameters
        var query = Operations.getRecentTransactions.Input.Query(limit: options.limit)
        applyFilterParameters(to: &query, from: options.filter)
        if let cursor = options.cursor {
            query.cursor = cursor
        }
        
        // Execute the request
        let response = try await client.getRecentTransactions(.init(query: query))
        
        // Process the response
        switch response {
        case .ok(let json):
            return extractTransactionData(from: json, source: source, options: options)
        case .unauthorized(_):
            handleUnauthorized()
            throw AuthenticationError.unauthorized
        default:
            throw APIError.unexpectedResponse(source: source.description)
        }
    }
    
    /// Fetches all transactions from the server
    private func fetchAllTransactionsFromServer(client: Client, options: FetchOptions) async throws -> TransactionResult {
        let source = TransactionSource.all
        
        // Create query parameters
        var query = Operations.getAllTransactions.Input.Query(limit: options.limit)
        applyFilterParameters(to: &query, from: options.filter)
        if let cursor = options.cursor {
            query.cursor = cursor
        }
        
        // Execute the request
        let response = try await client.getAllTransactions(.init(query: query))
        
        // Process the response
        switch response {
        case .ok(let json):
            return extractTransactionData(from: json, source: source, options: options)
        case .unauthorized(_):
            handleUnauthorized()
            throw AuthenticationError.unauthorized
        default:
            throw APIError.unexpectedResponse(source: source.description)
        }
    }
    
    /// Handles unauthorized error by logging out the user
    private func handleUnauthorized() {
        Logger.w("Unauthorized user. Logging out")
        UserAccount.shared.signOut()
    }
    
    /// Applies filter parameters to a query
    /// - Parameters:
    ///   - query: The query to modify
    ///   - filter: The filter criteria
    private func applyFilterParameters<T>(to query: inout T, from filter: TransactionFilter) {
        if let category = filter.category {
            applyFilterValue(category, to: &query, for: "category")
        }
        
        if let startDate = filter.startDate {
            applyFilterValue(startDate, to: &query, for: "startDate")
        }
        
        if let endDate = filter.endDate {
            applyFilterValue(endDate, to: &query, for: "endDate")
        }
        
        if let search = filter.search {
            applyFilterValue(search, to: &query, for: "search")
        }
    }
    
    /// Helper method to apply a specific filter parameter to a query
    /// - Parameters:
    ///   - value: The value to set
    ///   - query: The query to modify
    ///   - paramName: The name of the parameter to set
    private func applyFilterValue<T, V>(_ value: V, to query: inout T, for paramName: String) {
        if var q = query as? Operations.getAccountTransactions.Input.Query {
            switch paramName {
            case "category": q.category = value as? String
            case "startDate": q.startDate = value as? String
            case "endDate": q.endDate = value as? String
            case "search": q.search = value as? String
            case "cursor": q.cursor = value as? String
            default: break
            }
            query = q as! T
        } else if var q = query as? Operations.getItemTransactions.Input.Query {
            switch paramName {
            case "category": q.category = value as? String
            case "startDate": q.startDate = value as? String
            case "endDate": q.endDate = value as? String
            case "search": q.search = value as? String
            case "cursor": q.cursor = value as? String
            default: break
            }
            query = q as! T
        } else if var q = query as? Operations.getRecentTransactions.Input.Query {
            switch paramName {
            case "category": q.category = value as? String
            case "startDate": q.startDate = value as? String
            case "endDate": q.endDate = value as? String
            case "search": q.search = value as? String
            case "cursor": q.cursor = value as? String
            default: break
            }
            query = q as! T
        } else if var q = query as? Operations.getAllTransactions.Input.Query {
            switch paramName {
            case "category": q.category = value as? String
            case "startDate": q.startDate = value as? String
            case "endDate": q.endDate = value as? String
            case "search": q.search = value as? String
            case "cursor": q.cursor = value as? String
            default: break
            }
            query = q as! T
        }
    }
    
    /// Extracts transaction data from API response
    /// - Parameters:
    ///   - response: The API response
    ///   - source: The transaction source
    ///   - options: The fetch options
    /// - Returns: Processed transaction result
    private func extractTransactionData<T>(from response: T, source: TransactionSource, options: FetchOptions) -> TransactionResult {
        let (transactions, pagination) = extractTransactionsAndPagination(from: response, options: options)
        
        if transactions.isEmpty {
            return TransactionResult(transactions: [], pagination: nil, isFromCache: false)
        }
        
        // Log success
        Logger.i("Successfully fetched \(transactions.count) transactions for \(source.description)")
        
        // Save non-filtered, non-paginated results to cache
        if options.filter.isEmpty && options.cursor == nil {
            saveToCache(transactions: transactions, source: source)
        }
        
        // Build final result - either append to existing transactions or replace
        let finalTransactions = options.loadMore ? 
            self.transactions + transactions : transactions
            
        return TransactionResult(
            transactions: finalTransactions,
            pagination: pagination,
            isFromCache: false
        )
    }
    
    /// Extracts transactions and pagination data from response
    /// - Parameters:
    ///   - response: API response
    ///   - options: Fetch options
    /// - Returns: Tuple of transactions array and pagination info
    private func extractTransactionsAndPagination<T>(from response: T, options: FetchOptions) -> ([Transaction], PaginationInfo) {
        var transactions: [Transaction] = []
        var totalCount: Int = 0
        var responseLimit: Int? = nil
        var hasMore: Bool = false
        var nextCursor: String? = nil
        
        // Extract data from the different response types
        if let jsonResponse = response as? Operations.getAccountTransactions.Output.Ok {
            switch jsonResponse.body {
            case .json(let responseBody):
                transactions = responseBody.transactions ?? []
                if let responsePagination = responseBody.pagination {
                    totalCount = responsePagination.totalCount ?? 0
                    responseLimit = responsePagination.limit
                    hasMore = responsePagination.hasMore ?? false
                    nextCursor = responsePagination.nextCursor
                }
            }
        } else if let jsonResponse = response as? Operations.getItemTransactions.Output.Ok {
            switch jsonResponse.body {
            case .json(let responseBody):
                transactions = responseBody.transactions ?? []
                if let responsePagination = responseBody.pagination {
                    totalCount = responsePagination.totalCount ?? 0
                    responseLimit = responsePagination.limit
                    hasMore = responsePagination.hasMore ?? false
                    nextCursor = responsePagination.nextCursor
                }
            }
        } else if let jsonResponse = response as? Operations.getRecentTransactions.Output.Ok {
            switch jsonResponse.body {
            case .json(let responseBody):
                transactions = responseBody.transactions ?? []
                if let responsePagination = responseBody.pagination {
                    totalCount = responsePagination.totalCount ?? 0
                    responseLimit = responsePagination.limit
                    hasMore = responsePagination.hasMore ?? false
                    nextCursor = responsePagination.nextCursor
                }
            }
        } else if let jsonResponse = response as? Operations.getAllTransactions.Output.Ok {
            switch jsonResponse.body {
            case .json(let responseBody):
                transactions = responseBody.transactions ?? []
                if let responsePagination = responseBody.pagination {
                    totalCount = responsePagination.totalCount ?? 0
                    responseLimit = responsePagination.limit
                    hasMore = responsePagination.hasMore ?? false
                    nextCursor = responsePagination.nextCursor
                }
            }
        } else {
            Logger.e("Unknown response type")
        }
        
        // Create pagination info
        let pagination = PaginationInfo(
            totalCount: totalCount,
            limit: responseLimit ?? options.limit,
            hasMore: hasMore,
            nextCursor: nextCursor
        )
        
        Logger.d("Pagination info: total=\(pagination.totalCount), hasMore=\(pagination.hasMore), nextCursor=\(pagination.nextCursor ?? "none")")
        
        return (transactions, pagination)
    }
    
    /// Saves fetched transactions to the appropriate cache
    /// - Parameters:
    ///   - transactions: The transactions to cache
    ///   - source: The source of the transactions
    private func saveToCache(transactions: [Transaction], source: TransactionSource) {
        switch source {
        case .account(let id):
            if let accountId = Int(id) {
                transactionsManager.saveTransactions(transactions, for: accountId)
            }
            
        case .item, .recent, .all:
            // For these sources, save transactions by account groups
            let transactionsByAccountId = Dictionary(grouping: transactions) { $0.account_id }
            
            for (accountId, groupedTransactions) in transactionsByAccountId {
                transactionsManager.saveTransactions(
                    groupedTransactions,
                    for: Int(accountId)
                )
            }
        }
    }
}

// MARK: - Error Types

/// API error types
enum APIError: Error, LocalizedError {
    case unexpectedResponse(source: String)
    
    var errorDescription: String? {
        switch self {
        case .unexpectedResponse(let source):
            return "Unexpected response from server when fetching \(source)"
        }
    }
}

/// Authentication error types
enum AuthenticationError: Error, LocalizedError {
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized access. Please login again."
        }
    }
}
