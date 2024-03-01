//
//  User.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import Foundation
import Valet
import OpenAPIRuntime
import OpenAPIURLSession

struct User: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let token: String
}

private enum UserKeys: String {
    case id = "userId"
    case name = "userName"
    case token = "token"
}

@MainActor
class UserAccount: ObservableObject {
    @Published var currentUser: User? = nil
    @Published var client: Client? = nil

    private let valet = Valet.valet(with: Identifier(nonEmpty: "BabloApp")!, accessibility: .whenUnlocked)
    private let noAuthClient: Client = Client(serverURL: Client.getServerUrl(), transport: URLSessionTransport())
    
    init() {
        client = noAuthClient
    }
    
    func checkCurrentUser() {
        Logger.d("Checking if user is logged in. Retrieving data...")
        if let token = try? valet.string(forKey: UserKeys.token.rawValue), let userId = try? valet.string(forKey: UserKeys.id.rawValue), let userName = try? valet.string(forKey: UserKeys.name.rawValue) {
            Logger.d("Logged in as \(userName)")
            let user = User(id: userId, name: userName, token: token)
            currentUser = user
            updateClient()
        } else {
            Logger.e("User is not logged in!")
        }
    }
    
    func signIn(email: String, password: String) async throws {
        Logger.w("Attempting to sign in user \(email)")
        if let user = try? await UserRepository.login(client: noAuthClient, username: email, password: password) {
            Logger.d("Signin successfull. Storing user data...")
            currentUser = user
            try saveUserData()
        }
    }
    
    func createAccount(name: String, email: String, password: String) async throws {
        Logger.w("Attempting to create account for \(email)")
        if let user = try? await UserRepository.register(client: noAuthClient, username: email, password: password) {
            Logger.d("Create account is successfull. Storing user data...")
            currentUser = user
            try saveUserData()
        }
    }
    
    func signOut() {
        Logger.w("Signing out the user")
        try? valet.removeObject(forKey: "token")
        self.currentUser = nil
    }
    
    private func saveUserData() throws {
        if let theUser = currentUser {
            try valet.setString(theUser.id, forKey: UserKeys.id.rawValue)
            try valet.setString(theUser.name, forKey: UserKeys.name.rawValue)
            try valet.setString(theUser.token, forKey: UserKeys.token.rawValue)
        }
        updateClient()
    }
    
    private func updateClient() {
        if let theUser = currentUser {
            Logger.i("Updating current client to the auth one")
            client = Client(serverURL: Client.getServerUrl(), configuration: .init(dateTranscoder: ISO8601DateTranscoder(options: .withFractionalSeconds)), transport: URLSessionTransport(), middlewares: [AuthenticationMiddleware(token: theUser.token)] )
        } else {
            Logger.i("Updating current client to the no auth one")
            client = noAuthClient
        }
    }
}
