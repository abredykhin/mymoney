//
//  UserRepository.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/27/24.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

enum ApiError: Error {
    case unathorized(String)
    case genericError(String)
}

class UserRepository {
    private let client: Client
    
    init() {
        client = Client(serverURL: Client.getServerUrl(), transport: URLSessionTransport())
    }
    
    func login(username: String, password: String) async throws -> User {
        Logger.w("Requesting user login for \(username)")
        let response = try await client.userLogin(.init(body: .urlEncodedForm(.init(username: username, password: password))))
        
        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let json):
                Logger.d("Received OK response for sign in.")
                return User(id: json.user.id, name: json.user.username, token: json.token)
            }
        case .unauthorized(_):
            Logger.e("Received Unathorized response for sign in.")
            throw URLError(.userAuthenticationRequired)
        case .badRequest(_):
            Logger.e("Received BadRequest response for sign in.")
            throw URLError(.badURL)
        case .undocumented(_, _):
            Logger.e("Received unknown error response for sign in.")
            throw URLError(.badServerResponse)
        }
    }
    
    func register(username: String, password: String) async throws -> User {
        Logger.w("Requesting user registration for \(username)")
        let response = try await client.userRegister(.init(body: .urlEncodedForm(.init(username: username, password: password))))
        
        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let jsonBody):
                Logger.d("Received OK response for registration.")
                return User(id: jsonBody.user.id, name: jsonBody.user.username, token: jsonBody.token)
            }
        case .badRequest(_):
            Logger.e("Received BadRequest response for registration.")
            throw URLError(.badURL)
        case .conflict(_):
            Logger.e("Received Conflict response for registration.")
            throw URLError(.userAuthenticationRequired)
        case .undocumented(_, _):
            Logger.e("Received unknown error response for registration.")
            throw URLError(.badServerResponse)
        }
    }
}
