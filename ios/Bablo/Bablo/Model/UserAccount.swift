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
import CoreData

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

private enum BiometricKeys: String {
    case isBiometricEnabled = "biometricEnabled"
    case biometricPromptShown = "biometricPromptShown"
}


@MainActor
class UserAccount: ObservableObject {
    static let shared = UserAccount()
    
    @Published var currentUser: User? = nil
    @Published var client: Client? = nil
    @Published var isSignedIn: Bool = false
    @Published var isBiometricallyAuthenticated = false
    @Published var isBiometricEnabled = false
    
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
            isSignedIn = true
            updateClient()
        } else {
            Logger.e("User is not logged in!")
        }
    }
    
    func signIn(email: String, password: String) async throws {
        Logger.w("Attempting to sign in user \(email)")
        if let user = try? await login(client: noAuthClient, username: email, password: password) {
            Logger.d("Signin successfull. Storing user data...")
            currentUser = user
            isSignedIn = true
            try saveUserData()
        }
    }
    
    func createAccount(name: String, email: String, password: String) async throws {
        Logger.w("Attempting to create account for \(email)")
        if let user = try? await register(client: noAuthClient, username: email, password: password) {
            Logger.d("Create account is successfull. Storing user data...")
            currentUser = user
            isSignedIn = true
            try saveUserData()
        }
    }
    
    func signOut() {
        Logger.w("Signing out the user")
        try? valet.removeObject(forKey: "token")
        currentUser = nil
        isSignedIn = false
        clearCoreDataCache()
    }
    
    func checkBiometricSettings() {
        do {
            if try valet.containsObject(forKey: BiometricKeys.isBiometricEnabled.rawValue) {
                let stringValue = try valet.string(forKey: BiometricKeys.isBiometricEnabled.rawValue)
                isBiometricEnabled = (stringValue == "true")
                Logger.d("UserAccount: Loaded biometric settings - enabled: \(isBiometricEnabled)")
            } else {
                isBiometricEnabled = false
                Logger.d("UserAccount: No biometric settings found, defaulting to disabled")
            }
        } catch {
            Logger.e("Failed to read biometric settings: \(error)")
            isBiometricEnabled = false
        }
    }

    func enableBiometricAuthentication(_ enable: Bool) {
        do {
            let stringValue = enable ? "true" : "false"
            try valet.setString(stringValue, forKey: BiometricKeys.isBiometricEnabled.rawValue)
            isBiometricEnabled = enable
            Logger.i("Biometric authentication \(enable ? "enabled" : "disabled")")
        } catch {
            Logger.e("Failed to save biometric settings: \(error)")
        }
    }
    
    func requireBiometricAuth() {
        Logger.d("UserAccount: Requiring biometric auth - isBiometricEnabled: \(isBiometricEnabled)")
        if isBiometricEnabled {
            Logger.d("UserAccount: Set isBiometricallyAuthenticated to false")
            isBiometricallyAuthenticated = false
        }
    }
    
    func hasBiometricPromptBeenShown() -> Bool {
        do {
            if try valet.containsObject(forKey: BiometricKeys.biometricPromptShown.rawValue) {
                let stringValue = try valet.string(forKey: BiometricKeys.biometricPromptShown.rawValue)
                return (stringValue == "true")
            }
            return false
        } catch {
            return false
        }
    }
    
    func markBiometricPromptAsShown() {
        do {
            try valet.setString("true", forKey: BiometricKeys.biometricPromptShown.rawValue)
        } catch {
            Logger.e("Failed to save biometric prompt status: \(error)")
        }
    }
    
    private func clearCoreDataCache() {
        let context = CoreDataStack.shared.viewContext
        let entityNames = ["BankEntity", "AccountEntity", "TransactionEntity"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
                Logger.i("Cleared \(entityName) cache")
            } catch {
                Logger.e("Failed to clear \(entityName) cache: \(error)")
            }
        }
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
    
    private func login(client: Client, username: String, password: String) async throws -> User {
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
    
    private func register(client: Client, username: String, password: String) async throws -> User {
        Logger.w("Requesting user registration for \(username) with password \(password)")
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
