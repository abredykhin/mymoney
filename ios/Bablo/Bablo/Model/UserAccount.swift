//
//  User.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//  Updated for Supabase Migration - Phase 2
//

import Foundation
import Valet
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

struct Profile: Codable, Equatable {
    let id: String
    let username: String
    let monthlyIncome: Double
    let monthlyMandatoryExpenses: Double

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case monthlyIncome = "monthly_income"
        case monthlyMandatoryExpenses = "monthly_mandatory_expenses"
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
    @Published var profile: Profile? = nil
    @Published var isSignedIn: Bool = false
    @Published var isBiometricallyAuthenticated = false
    @Published var isBiometricEnabled = false

    var isBudgetSetup: Bool {
        guard let profile = profile else { return false }
        return profile.monthlyIncome > 0
    }

    private let valet = Valet.valet(with: Identifier(nonEmpty: "BabloApp")!, accessibility: .whenUnlocked)
    private let supabase = SupabaseManager.shared.client

    init() {
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
            Task {
                await fetchProfile()
            }
        } catch {
            Logger.e("UserAccount: Failed to save user data: \(error)")
        }
    }

    /// Fetch user profile from profiles table
    func fetchProfile() async {
        guard let user = currentUser else { return }
        
        do {
            let fetchedProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.profile = fetchedProfile
                Logger.i("UserAccount: Profile fetched for \(fetchedProfile.username). Budget setup: \(isBudgetSetup)")
            }
        } catch {
            Logger.e("UserAccount: Failed to fetch profile: \(error)")
        }
    }
    
    /// Update user profile budget data
    func updateProfileBudget(monthlyIncome: Double, monthlyExpenses: Double) async throws {
        guard let user = currentUser else { return }
        
        Logger.i("UserAccount: Updating budget - Income: \(monthlyIncome), Expenses: \(monthlyExpenses)")
        
        struct BudgetUpdate: Encodable {
            let monthly_income: Double
            let monthly_mandatory_expenses: Double
        }
        
        let updateData = BudgetUpdate(
            monthly_income: monthlyIncome,
            monthly_mandatory_expenses: monthlyExpenses
        )
        
        do {
            try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: user.id)
                .execute()
            
            // Refresh local profile
            await fetchProfile()
            Logger.i("UserAccount: Budget updated successfully")
        } catch {
            Logger.e("UserAccount: Failed to update budget: \(error)")
            throw error
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
                }
            } else {
                Logger.d("User is not logged in")
            }
        }
    }
    
    /// @deprecated Legacy sign in method - NO LONGER SUPPORTED
    /// Use Sign in with Apple via Supabase instead
    func signIn(email: String, password: String) async throws {
        Logger.e("Legacy sign in attempted for \(email) - method no longer supported")
        throw NSError(
            domain: "UserAccount",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Legacy password authentication is no longer supported. Please sign out and use Sign in with Apple."
            ]
        )
    }

    /// @deprecated Legacy account creation method - NO LONGER SUPPORTED
    /// Use Sign in with Apple via Supabase instead
    func createAccount(name: String, email: String, password: String) async throws {
        Logger.e("Legacy account creation attempted for \(email) - method no longer supported")
        throw NSError(
            domain: "UserAccount",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Legacy account creation is no longer supported. Please use Sign in with Apple."
            ]
        )
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
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []

                // Merge the changes into the in-memory context
                let changes = [NSDeletedObjectsKey: objectIDArray]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])

                try context.save()
                Logger.i("Cleared \(entityName) cache (\(objectIDArray.count) objects)")
            } catch {
                Logger.e("Failed to clear \(entityName) cache: \(error)")
            }
        }

        // Reset the context to clear all in-memory objects
        context.reset()
        Logger.i("CoreData context reset complete")
    }
    
    private func saveUserData() throws {
        if let theUser = currentUser {
            try valet.setString(theUser.id, forKey: UserKeys.id.rawValue)
            try valet.setString(theUser.name, forKey: UserKeys.name.rawValue)
            try valet.setString(theUser.token, forKey: UserKeys.token.rawValue)
        }
    }
    
    // Legacy login/register methods removed - backend no longer exists
    // All authentication now goes through Supabase Auth (Sign in with Apple)
}
