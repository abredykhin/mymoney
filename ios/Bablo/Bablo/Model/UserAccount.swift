//
//  User.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//  Updated for Supabase Migration - Phase 2
//

import Foundation
import Valet
import OpenAPIRuntime
import OpenAPIURLSession
import CoreData
import Supabase

struct User: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let token: String
    let email: String?

    /// Create User from Supabase session
    static func from(session: Session) -> User {
        let name = session.user.userMetadata["full_name"]?.stringValue ??
                   session.user.email?.components(separatedBy: "@").first ??
                   "User"
        return User(
            id: session.user.id.uuidString,
            name: name,
            token: session.accessToken,
            email: session.user.email
        )
    }
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
    private let supabase = SupabaseManager.shared.client

    init() {
        client = noAuthClient

        // Listen to Supabase auth state changes
        Task {
            await observeAuthStateChanges()
        }
    }

    /// Observe Supabase auth state changes
    private func observeAuthStateChanges() async {
        for await state in supabase.auth.authStateChanges {
            Logger.d("UserAccount: Auth state changed: \(state.event)")

            switch state.event {
            case .signedIn:
                if let session = state.session {
                    Logger.i("UserAccount: User signed in via Supabase")
                    await handleSupabaseSession(session)
                }
            case .signedOut:
                Logger.i("UserAccount: User signed out")
                await MainActor.run {
                    self.currentUser = nil
                    self.isSignedIn = false
                    self.client = noAuthClient
                }
            case .tokenRefreshed:
                if let session = state.session {
                    Logger.d("UserAccount: Token refreshed")
                    await handleSupabaseSession(session)
                }
            default:
                break
            }
        }
    }

    /// Handle Supabase session and update user state
    private func handleSupabaseSession(_ session: Session) async {
        let user = User.from(session: session)

        await MainActor.run {
            self.currentUser = user
            self.isSignedIn = true
        }

        do {
            try saveUserData()
        } catch {
            Logger.e("UserAccount: Failed to save user data: \(error)")
        }
    }
    
    func checkCurrentUser() {
        Logger.d("Checking if user is logged in...")

        Task {
            // First, check if there's a Supabase session
            do {
                let session = try await supabase.auth.session
                Logger.d("Found active Supabase session")
                await handleSupabaseSession(session)
                return
            } catch {
                Logger.d("No active Supabase session: \(error)")
            }

            // Fall back to legacy credentials check (for migration period)
            if let token = try? valet.string(forKey: UserKeys.token.rawValue),
               let userId = try? valet.string(forKey: UserKeys.id.rawValue),
               let userName = try? valet.string(forKey: UserKeys.name.rawValue) {
                Logger.d("Found legacy credentials for \(userName)")
                let user = User(id: userId, name: userName, token: token, email: nil)
                await MainActor.run {
                    currentUser = user
                    isSignedIn = true
                    updateClient()
                }
            } else {
                Logger.d("User is not logged in")
            }
        }
    }
    
    /// @deprecated Legacy sign in method - kept for backward compatibility
    /// Use Sign in with Apple via Supabase instead
    func signIn(email: String, password: String) async throws {
        Logger.w("Attempting to sign in user \(email) (legacy method)")
        if let user = try? await login(client: noAuthClient, username: email, password: password) {
            Logger.d("Signin successfull. Storing user data...")
            currentUser = user
            isSignedIn = true
            try saveUserData()
        }
    }

    /// @deprecated Legacy account creation method - kept for backward compatibility
    /// Use Sign in with Apple via Supabase instead
    func createAccount(name: String, email: String, password: String) async throws {
        Logger.w("Attempting to create account for \(email) (legacy method)")
        if let user = try? await register(client: noAuthClient, username: email, password: password) {
            Logger.d("Create account is successfull. Storing user data...")
            currentUser = user
            isSignedIn = true
            try saveUserData()
        }
    }
    
    func signOut() {
        Logger.w("Signing out the user")

        Task {
            // Sign out from Supabase
            do {
                try await supabase.auth.signOut()
                Logger.i("Signed out from Supabase")
            } catch {
                Logger.e("Failed to sign out from Supabase: \(error)")
            }

            // Clear legacy credentials
            try? valet.removeObject(forKey: UserKeys.token.rawValue)
            try? valet.removeObject(forKey: UserKeys.id.rawValue)
            try? valet.removeObject(forKey: UserKeys.name.rawValue)

            await MainActor.run {
                currentUser = nil
                isSignedIn = false
                clearCoreDataCache()
            }
        }
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
            Logger.d("UserAccount: Saving biometric setting: \(stringValue)")
            try valet.setString(stringValue, forKey: BiometricKeys.isBiometricEnabled.rawValue)
            isBiometricEnabled = enable
            Logger.i("Biometric authentication \(enable ? "enabled" : "disabled")")
        } catch {
            Logger.e("Failed to save biometric settings: \(error)")
        }
    }
    
    func requireBiometricAuth() {
        Logger.d("UserAccount: Checking if auth required - isBiometricEnabled: \(isBiometricEnabled)")
        
        if isBiometricEnabled && AuthManager.shared.shouldRequireAuthentication() {
            Logger.d("UserAccount: Setting isBiometricallyAuthenticated to false")
            isBiometricallyAuthenticated = false
        } else {
            Logger.d("UserAccount: Not requiring auth: biometrics \(isBiometricEnabled ? "enabled" : "disabled"), auth check: \(AuthManager.shared.shouldRequireAuthentication())")
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
    
    /// @deprecated Legacy login method - backend is being deprecated
    /// This method is kept only for backward compatibility during migration
    private func login(client: Client, username: String, password: String) async throws -> User {
        Logger.w("Requesting user login for \(username) (LEGACY - backend deprecated)")
        let response = try await client.userLogin(.init(body: .urlEncodedForm(.init(username: username, password: password))))

        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let json):
                Logger.d("Received OK response for sign in.")
                return User(id: json.user.id, name: json.user.username, token: json.token, email: username)
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

    /// @deprecated Legacy registration method - backend is being deprecated
    /// This method is kept only for backward compatibility during migration
    private func register(client: Client, username: String, password: String) async throws -> User {
        Logger.w("Requesting user registration for \(username) (LEGACY - backend deprecated)")
        let response = try await client.userRegister(.init(body: .urlEncodedForm(.init(username: username, password: password))))

        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let jsonBody):
                Logger.d("Received OK response for registration.")
                return User(id: jsonBody.user.id, name: jsonBody.user.username, token: jsonBody.token, email: username)
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
