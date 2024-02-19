//
//  AuthViewModel.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import Foundation
import Valet

protocol AuthFormValidationProtocol {
    var formIsValid: Bool { get }
}

private enum UserKeys: String {
    case id = "userId"
    case name = "userName"
    case token = "token"
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User? = nil
    private let defaults = UserDefaults.standard
    private let userRepository = UserRepository()
    private let valet = Valet.valet(with: Identifier(nonEmpty: "BabloApp")!, accessibility: .whenUnlocked)

    init() {
        if (isUserLoggedIn()) {
            Logger.d("User is logged in. Retrieving data...")
            if let token = try? valet.string(forKey: UserKeys.token.rawValue), let userId = try? valet.string(forKey: UserKeys.id.rawValue), let userName = try? valet.string(forKey: UserKeys.name.rawValue) {
                currentUser = User(id: userId, name: userName, token: token)
                Logger.d("Logged in as \(userName)")
            } else {
                Logger.e("User is not logged in!")
            }
        }
    }
    
    private func isUserLoggedIn() -> Bool {
        if let _ = try? valet.string(forKey: UserKeys.token.rawValue) {
            return true
        } else {
            return false
        }
    }
    
    func signIn(email: String, password: String) async throws {
        Logger.w("Attempting to sign in user \(email)")
        if let user = try? await userRepository.login(username: email, password: password) {
            Logger.d("Signin successfull. Storing user data...")
            currentUser = user
            try saveUserData()
        }
    }
    
    func createAccount(name: String, email: String, password: String) async throws {
        Logger.w("Attempting to create account for \(email)")
        if let user = try? await userRepository.register(username: email, password: password) {
            Logger.d("Create account is successfull. Storing user data...")
            currentUser = user
            try saveUserData()
        }
    }
    
    func signOut() {
        Logger.w("Signing out the user")
        try? valet.removeObject(forKey: "token")
    }
    
    private func saveUserData() throws {
        if let theUser = currentUser {
            try valet.setString(theUser.id, forKey: UserKeys.id.rawValue)
            try valet.setString(theUser.name, forKey: UserKeys.name.rawValue)
            try valet.setString(theUser.token, forKey: UserKeys.token.rawValue)
        }
    }
}
