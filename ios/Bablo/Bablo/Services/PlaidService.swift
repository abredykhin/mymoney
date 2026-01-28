//
//  PlaidService.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 3
//  Handles Plaid Link token creation via Supabase Edge Functions
//

import Foundation
import Supabase
import LinkKit

/// Response from plaid-link-token Edge Function
struct PlaidLinkTokenResponse: Codable {
    let link_token: String
    let expiration: String
    let request_id: String
}

/// Response from save-item endpoint (legacy for now)
struct SaveItemResponse: Codable {
    // Add fields as needed
}

/// Service for Plaid-related operations using Supabase Edge Functions
@MainActor
class PlaidService: ObservableObject {
    private let supabase = SupabaseManager.shared.client

    /// Store the current Plaid handler for OAuth redirect handling
    /// The handler must be retained for the duration of the Link flow
    /// and will be needed to respond to OAuth Universal Link redirects
    var currentHandler: Handler? = nil

    /// Create a new Plaid Link token for connecting a bank account
    /// - Parameter itemId: Optional item ID for update mode
    /// - Returns: Link token string
    func createLinkToken(itemId: Int? = nil) async throws -> String {
        Logger.i("PlaidService: Creating link token (itemId: \(itemId?.description ?? "nil"))")

        var body: [String: Any] = [:]
        if let itemId = itemId {
            body["itemId"] = itemId
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        Logger.d("PlaidService: Invoking plaid-link-token function")

        let linkTokenResponse: PlaidLinkTokenResponse = try await supabase.functions.invoke(
            "plaid-link-token",
            options: FunctionInvokeOptions(body: bodyData)
        )

        Logger.d("PlaidService: Received response from plaid-link-token function")

        Logger.i("PlaidService: Successfully created link token")
        return linkTokenResponse.link_token
    }

    /// Exchange public token for access token and save item
    /// - Parameters:
    ///   - publicToken: Public token from Plaid Link
    ///   - institutionId: Institution ID from Plaid
    func saveNewItem(publicToken: String, institutionId: String) async throws {
        Logger.i("PlaidService: Saving new item (institution: \(institutionId))")

        let body: [String: Any] = [
            "public_token": publicToken,
            "institution_id": institutionId
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        Logger.d("PlaidService: Invoking save-item function")

        do {
            let _: SaveItemResponse = try await supabase.functions.invoke(
                "save-item",
                options: FunctionInvokeOptions(body: bodyData)
            )

            Logger.i("PlaidService: Successfully saved new item")
        } catch {
            Logger.e("PlaidService: Failed to save item: \(error)")
            throw PlaidServiceError.saveItemFailed(error.localizedDescription)
        }
    }

    /// Update an existing Plaid item (re-authenticate)
    /// - Parameter itemId: The item ID to update
    /// - Returns: Link token for update mode
    func updateItem(itemId: Int) async throws -> String {
        Logger.i("PlaidService: Updating item \(itemId)")
        return try await createLinkToken(itemId: itemId)
    }
}

// MARK: - Error Types

enum PlaidServiceError: LocalizedError {
    case invalidResponse
    case missingClient
    case linkTokenCreationFailed(String)
    case saveItemFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Plaid service"
        case .missingClient:
            return "Client not available"
        case .linkTokenCreationFailed(let message):
            return "Failed to create link token: \(message)"
        case .saveItemFailed(let message):
            return "Failed to save item: \(message)"
        }
    }
}
