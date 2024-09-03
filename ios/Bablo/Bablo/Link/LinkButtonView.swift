    //
    //  LinkButtonView.swift
    //  mymoney
    //
    //  Created by Anton Bredykhin on 2/20/24.
    //

import SwiftUI
import LinkKit

    //@MainActor
struct LinkButtonView : View {
    @State var shouldPresentLink = false
    @StateObject var userAccount = UserAccount.shared
    @EnvironmentObject var bankAccounts: BankAccounts
    @State var linkController: LinkController? = nil
    
    var body: some View {
        ZStack(alignment: .leading) {
            Button {
                Task {
                    debugPrint("Add new account pressed!")
                    shouldPresentLink = true
                }
            } label: {
                Text("Link new account")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.primary)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .shadow(radius: 2)
            }
        }
        .sheet (
            isPresented: $shouldPresentLink,
            onDismiss: {
                shouldPresentLink = false
            },
            content: { [linkController] in
                if let linkController {
                    linkController
                        .ignoresSafeArea(.all)
                } else {
                    Text("Error: LinkController not initialized")
                }
            }
        )
        .task {
            do {
                Logger.d("Requesting a link token...")
                let response = try await userAccount.client?.getLinkToken()
                
                switch response {
                case .ok(okResponse: let okResponse):
                    switch okResponse.body {
                    case .json(let json):
                        Logger.i("Received OK response for Link token")
                        let config = try await generateLinkConfig(linkToken: json.link_token)
                        let handler = Plaid.create(config)
                        switch handler {
                        case .success(let handler):
//                                let tmp = LinkController(handler: handler)
//                            DispatchQueue.main.async {
                            self.linkController = LinkController(handler: handler)
                                
//                                if let ctrl =  self.linkController {
                                    Logger.i("LinkController initialized")
//                                }
//                            }
                        case .failure(let error):
                            Logger.e("Failed to init Plaid: \(error)")
                        }
                    }
                case .undocumented(statusCode: let statusCode, _):
                    Logger.e("Recieved error from server. statusCode = \(statusCode)")
                        //throw URLError(.badServerResponse)
                case .none:
                    Logger.e("FAIL")
                        //throw URLError(.badServerResponse)
                }
            } catch {
                Logger.e("Failed to init Plaid: \(error)")
            }
        }
    }
    
    private func generateLinkConfig(linkToken: String) async throws -> LinkTokenConfiguration {
        Logger.d("Creating Link config with token \(linkToken)")
        
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Logger.i("Link was finished succesfully! \(success)")
            Task {
                try? await self.saveNewItem(token: success.publicToken, institutionId: success.metadata.institution.id)
            }
        }
        config.onExit = { exit in
            Logger.e("User exited link early \(exit)")
            self.shouldPresentLink = false
        }
        config.onEvent = { event in
            Logger.d("Hit an event \(event.eventName)")
        }
        return config
        
    }
    
    private func saveNewItem(token: String, institutionId: String) async throws {
        guard let client = userAccount.client else { return }
        
        Logger.d("Saving new item to server...")
        
        let response = try await client.saveNewItem(body: .urlEncodedForm(.init(institutionId: institutionId, publicToken: token)))
        switch(response) {
        case .ok(_):
            try? await bankAccounts.refreshAccounts()
            break
        case .undocumented(_, _):
            throw URLError(.badServerResponse)
        }
    }
}
