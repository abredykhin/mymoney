//
//  LinkViewModel.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/20/24.
//

import Foundation
import LinkKit

@MainActor
class LinkViewModel: ObservableObject {
    @Published var shouldShowLink: Bool = false
    
    private let itemsRepository: ItemsRepository
    var handler: Result<Handler, Plaid.CreateError>? = nil
    
    init(user: User) {
        itemsRepository = ItemsRepository(user: user)
    }
    
    func getLinkToken() async {
        if let token = try? await itemsRepository.getLinkToken() {
            let config = generateLinkConfig(linkToken: token)
            handler = Plaid.create(config)
            shouldShowLink = true
        }
    }
    
    private func generateLinkConfig(linkToken: String) -> LinkTokenConfiguration {
        Logger.d("Creating Link config with token \(linkToken)")
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Logger.i("Link was finished succesfully! \(success)")
            self.shouldShowLink = false
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
