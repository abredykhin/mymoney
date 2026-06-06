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
    let firstName: String?
    let monthlyIncome: Double
    let monthlyMandatoryExpenses: Double
    let spendingPlanMode: SpendingPlanMode
    let incomeBasis: IncomeBasis
    let trackedSpendingCategories: [String]
    let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case monthlyIncome = "monthly_income"
        case monthlyMandatoryExpenses = "monthly_mandatory_expenses"
        case spendingPlanMode = "spending_plan_mode"
        case incomeBasis = "income_basis"
        case trackedSpendingCategories = "tracked_spending_categories"
        case timeZone = "time_zone"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        monthlyIncome = try c.decode(Double.self, forKey: .monthlyIncome)
        monthlyMandatoryExpenses = try c.decode(Double.self, forKey: .monthlyMandatoryExpenses)
        let rawSpendingPlanMode = try c.decodeIfPresent(String.self, forKey: .spendingPlanMode)
        spendingPlanMode = rawSpendingPlanMode.flatMap(SpendingPlanMode.init(rawValue:)) ?? .safeToSpend
        let rawIncomeBasis = try c.decodeIfPresent(String.self, forKey: .incomeBasis)
        incomeBasis = rawIncomeBasis.flatMap(IncomeBasis.init(rawValue:)) ?? .projected
        trackedSpendingCategories = (try? c.decodeIfPresent([String].self, forKey: .trackedSpendingCategories)) ?? []
        timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone)
    }
}



struct FixedExpenseEntry {
    let category: FixedExpenseCategory
    let amount: Int
}

private struct ManualStreamWrite: Encodable {
    let user_id: String
    let description: String
    let frequency: String
    let average_amount: Double
    let last_amount: Double
    let monthly_amount: Double
    let type: String
    let status: String
    let is_active: Bool
    let is_manual: Bool
    let match_pattern: String
}

private struct ManualStreamIdentifier: Decodable {
    let id: Int
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
    @Published var spendingPlanMode: SpendingPlanMode = .safeToSpend
    @Published var incomeBasis: IncomeBasis = .projected
    @Published var isSignedIn: Bool = false
    @Published var isBiometricallyAuthenticated = false
    @Published var isBiometricEnabled = false

    var isBudgetSetup: Bool {
        guard let profile = profile else { return false }
        return profile.monthlyIncome > 0
    }

    var hasCompletedOnboarding: Bool {
        guard let currentUser else { return false }
        return UserDefaults.standard.bool(forKey: onboardingCompletionKey(for: currentUser.id))
    }

    var needsOnboarding: Bool {
        !hasCompletedOnboarding && !isBudgetSetup
    }

    private let spendingPlanModeStore = SpendingPlanModeStore()
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
                    self.profile = nil
                    self.spendingPlanMode = .safeToSpend
                    self.incomeBasis = .projected
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
        let isDifferentUser = currentUser?.id != user.id

        await MainActor.run {
            if isDifferentUser {
                self.profile = nil
            }
            self.currentUser = user
            self.spendingPlanMode = self.spendingPlanModeStore.mode(for: user.id)
            self.isSignedIn = true
        }

        Task {
            await fetchProfile()
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

            await updateProfileTimeZoneIfNeeded(fetchedProfile, userId: user.id)
            
            await MainActor.run {
                self.profile = fetchedProfile
                self.spendingPlanMode = fetchedProfile.spendingPlanMode
                self.spendingPlanModeStore.save(fetchedProfile.spendingPlanMode, for: user.id)
                self.incomeBasis = fetchedProfile.incomeBasis
                Logger.i("UserAccount: Profile fetched for \(fetchedProfile.username). Budget setup: \(isBudgetSetup)")
            }
        } catch let error as PostgrestError where error.code == "PGRST116" {
            Logger.e("UserAccount: Profile not found (User likely deleted). Force signing out.")
            signOut()
        } catch {
            Logger.e("UserAccount: Failed to fetch profile: \(error)")
        }
    }

    private func updateProfileTimeZoneIfNeeded(_ profile: Profile, userId: String) async {
        let currentTimeZone = Calendar.bablo.timeZone.identifier
        guard profile.timeZone != currentTimeZone else { return }

        struct TimeZoneUpdate: Encodable {
            let time_zone: String
        }

        do {
            try await supabase
                .from("profiles")
                .update(TimeZoneUpdate(time_zone: currentTimeZone))
                .eq("id", value: userId)
                .execute()
            Logger.i("UserAccount: Updated profile timezone to \(currentTimeZone)")
        } catch {
            Logger.e("UserAccount: Failed to update profile timezone: \(error)")
        }
    }

    /// Save the user's casual first name collected during onboarding.
    func updateProfileFirstName(_ firstName: String) async throws {
        guard let user = currentUser else { return }

        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        struct FirstNameUpdate: Encodable {
            let first_name: String
        }

        do {
            try await supabase
                .from("profiles")
                .update(FirstNameUpdate(first_name: trimmedName))
                .eq("id", value: user.id)
                .execute()

            await fetchProfile()

            currentUser = User(
                id: user.id,
                name: trimmedName,
                token: user.token,
                email: user.email
            )
        } catch {
            Logger.e("UserAccount: Failed to update first name: \(error)")
            throw error
        }
    }
    
    /// Save the user's selected flexible spending categories (onboarding Step 5).
    func updateTrackedCategories(_ categories: [String]) async throws {
        guard let user = currentUser else { return }

        struct CategoryUpdate: Encodable {
            let tracked_spending_categories: [String]
        }

        try await supabase
            .from("profiles")
            .update(CategoryUpdate(tracked_spending_categories: categories))
            .eq("id", value: user.id)
            .execute()

        await fetchProfile()
    }

    /// Save the user's selected Home hero spending plan mode.
    func updateSpendingPlanMode(_ mode: SpendingPlanMode) async throws {
        guard let user = currentUser else { return }

        let previousMode = spendingPlanMode
        spendingPlanMode = mode
        spendingPlanModeStore.save(mode, for: user.id)

        struct SpendingPlanModeUpdate: Encodable {
            let spending_plan_mode: String
        }

        do {
            try await supabase
                .from("profiles")
                .update(SpendingPlanModeUpdate(spending_plan_mode: mode.rawValue))
                .eq("id", value: user.id)
                .execute()

            await fetchProfile()
        } catch {
            spendingPlanMode = previousMode
            spendingPlanModeStore.save(previousMode, for: user.id)
            Logger.e("UserAccount: Failed to update spending plan mode: \(error)")
            throw error
        }
    }

    /// Persist the user's chosen income basis (projected vs cash-only).
    func updateIncomeBasis(_ basis: IncomeBasis) async throws {
        guard let user = currentUser else { return }

        let previous = incomeBasis
        incomeBasis = basis

        struct IncomeBasisUpdate: Encodable {
            let income_basis: String
        }

        do {
            try await supabase
                .from("profiles")
                .update(IncomeBasisUpdate(income_basis: basis.rawValue))
                .eq("id", value: user.id)
                .execute()

            await fetchProfile()
        } catch {
            incomeBasis = previous
            Logger.e("UserAccount: Failed to update income basis: \(error)")
            throw error
        }
    }

    /// Upsert manual recurring streams for fixed expense categories (onboarding Step 4).
    /// Categories with amount == 0 are skipped (user left them as "Skip").
    func saveFixedExpenses(_ entries: [FixedExpenseEntry]) async throws {
        guard let user = currentUser else { return }

        var totalExpenses: Double = 0

        for entry in entries where entry.amount > 0 {
            totalExpenses += Double(entry.amount)
            let stream = ManualStreamWrite(
                user_id: user.id,
                description: entry.category.displayName,
                frequency: "MONTHLY",
                average_amount: Double(entry.amount),
                last_amount: Double(entry.amount),
                monthly_amount: Double(entry.amount),
                type: "expense",
                status: "MANUAL",
                is_active: true,
                is_manual: true,
                match_pattern: entry.category.rawValue
            )

            try await saveManualRecurringStream(stream, for: user.id)
        }

        // Keep profile total in sync with what was entered
        if totalExpenses > 0 {
            try await updateProfileBudget(
                monthlyIncome: profile?.monthlyIncome ?? 0,
                monthlyExpenses: totalExpenses
            )
        }
    }

    private func saveManualRecurringStream(_ stream: ManualStreamWrite, for userID: String) async throws {
        let existingStreams: [ManualStreamIdentifier] = try await supabase
            .from("recurring_streams_table")
            .select("id")
            .eq("user_id", value: userID)
            .eq("match_pattern", value: stream.match_pattern)
            .eq("is_manual", value: true)
            .limit(1)
            .execute()
            .value

        if let existingStream = existingStreams.first {
            try await supabase
                .from("recurring_streams_table")
                .update(stream)
                .eq("id", value: existingStream.id)
                .execute()
        } else {
            try await supabase
                .from("recurring_streams_table")
                .insert(stream)
                .execute()
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
            } catch let error as AuthError {
                Logger.e("Supabase session invalid (AuthError: \(error)). Force signing out.")
                signOut()
                return
            } catch {
                Logger.d("No active Supabase session: \(error)")
                signOut()
                return
            }

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



            await MainActor.run {
                currentUser = nil
                profile = nil
                isSignedIn = false
                clearCoreDataCache()
                // Clear AccountsService cache
                UserDefaults.standard.removeObject(forKey: "cached_banks_v2")
                Logger.i("Cleared AccountsService cache")
            }
        }
    }

    func markOnboardingCompleted() {
        guard let currentUser else { return }
        UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: currentUser.id))
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
    
    func lockApp() {
        if isBiometricEnabled {
            Logger.d("UserAccount: Locking app (invalidating biometric session)")
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

    private func onboardingCompletionKey(for userID: String) -> String {
        "hasCompletedOnboarding.\(userID)"
    }
    

    
    // Legacy login/register methods removed - backend no longer exists
    // All authentication now goes through Supabase Auth (Sign in with Apple)
}
