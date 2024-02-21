//
//  ItemsRepository.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

typealias LinkTokenType = Components.Schemas.LinkTokenResponse

@MainActor
class ItemsRepository: ObservableObject {
    private let client: Client
    private let user: User
    
    init(user: User) {
        self.user = user
        client = Client(serverURL: Client.getServerUrl(), transport: URLSessionTransport(), middlewares: [AuthenticationMiddleware(authorizationHeaderFieldValue: user.token)])
    }
    
    func getLinkToken() async throws -> String {
        Logger.d("Requesting a link token...")
        let response = try await client.getLinkToken()
        
        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let json):
                Logger.i("Received OK response for Link token")
                return json.link_token
            }
        case .undocumented(statusCode: let statusCode, _):
            Logger.e("Recieved error from server. statusCode = \(statusCode)")
            throw URLError(.badServerResponse)
        }
    }
}
