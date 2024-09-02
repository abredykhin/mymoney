//
//  LinkViewModel.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/20/24.
//

import Foundation
import LinkKit
import OpenAPIURLSession

@MainActor
class LinkViewModel: ObservableObject {
    @Published var shouldShowLink: Bool = false
    
    var client: Client? = nil
    var bankAccountsManager: BankAccountsManager? = nil
    var handler: Result<Handler, Plaid.CreateError>? = nil
    
    func getLinkToken() async throws {
        Logger.d("Requesting a link token...")
        let response = try await client?.getLinkToken()
        
        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let json):
                Logger.i("Received OK response for Link token")
                let config = try await generateLinkConfig(linkToken: json.link_token)
                handler = Plaid.create(config)
                shouldShowLink = true
                return
            }
        case .undocumented(statusCode: let statusCode, _):
            Logger.e("Recieved error from server. statusCode = \(statusCode)")
            throw URLError(.badServerResponse)
        case .none:
            throw URLError(.badServerResponse)
        }
    }
    
    private func saveNewItem(token: String, institutionId: String) async throws {
        guard let client = client, let bankAccountsManager = bankAccountsManager else { return }
            
        Logger.d("Saving new item to server...")

        let response = try await client.saveNewItem(body: .urlEncodedForm(.init(institutionId: institutionId, publicToken: token)))
        switch(response) {
        case .ok(_):
            try? await bankAccountsManager.refreshAccounts()
            break
        case .undocumented(_, _):
            throw URLError(.badServerResponse)
        }
    }
    
    private func generateLinkConfig(linkToken: String) async throws -> LinkTokenConfiguration {
        Logger.d("Creating Link config with token \(linkToken)")
        
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Logger.i("Link was finished succesfully! \(success)")
            self.shouldShowLink = false
            Task {
                try? await self.saveNewItem(token: success.publicToken, institutionId: success.metadata.institution.id)
            }
        }
        config.onExit = { exit in
            Logger.e("User exited link early \(exit)")
            self.shouldShowLink = false
        }
        config.onEvent = { event in
            Logger.d("Hit an event \(event.eventName)")
        }
        return config
        
    }
}
