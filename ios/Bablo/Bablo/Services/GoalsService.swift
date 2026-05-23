//
//  GoalsService.swift
//  Bablo
//

import Foundation
import Supabase

// MARK: - Data Models

struct SavingsGoal: Codable, Identifiable, Equatable {
    let id: Int
    let user_id: String
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let etaDate: String?
    let categoryIcon: String
    let isActive: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case name
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case etaDate = "eta_date"
        case categoryIcon = "category_icon"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var progressPercent: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, currentAmount / targetAmount)
    }
}

struct SavingsDeposit: Codable, Identifiable, Equatable {
    let id: Int
    let goalId: Int
    let user_id: String
    let amount: Double
    let depositDate: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case user_id
        case amount
        case depositDate = "deposit_date"
        case createdAt = "created_at"
    }
}

// MARK: - Service

@MainActor
class GoalsService: ObservableObject {
    @Published var savingsGoals: [SavingsGoal] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetch all active savings goals for the user
    func fetchSavingsGoals() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let goals: [SavingsGoal] = try await supabase
                .from("savings_goals_table")
                .select("*")
                .eq("is_active", value: true)
                .order("created_at", ascending: true)
                .execute()
                .value

            self.savingsGoals = goals
            Logger.i("GoalsService: Loaded \(goals.count) savings goals successfully")
        } catch {
            Logger.e("GoalsService: Failed to fetch savings goals: \(error)")
            self.error = error
            throw error
        }
    }

    /// Create a new savings goal
    func createSavingsGoal(name: String, targetAmount: Double, etaDate: String?, categoryIcon: String = "✈️") async throws -> SavingsGoal {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetService.BudgetError.noUser
        }

        struct CreateGoalRequest: Codable {
            let user_id: String
            let name: String
            let target_amount: Double
            let eta_date: String?
            let category_icon: String
        }

        let body = CreateGoalRequest(
            user_id: userId,
            name: name,
            target_amount: targetAmount,
            eta_date: etaDate,
            category_icon: categoryIcon
        )

        do {
            let goal: SavingsGoal = try await supabase
                .from("savings_goals_table")
                .insert(body)
                .select("*")
                .single()
                .execute()
                .value

            Logger.i("GoalsService: Savings goal created successfully: \(goal.name)")
            try await fetchSavingsGoals()
            return goal
        } catch {
            Logger.e("GoalsService: Failed to create savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    /// Delete a savings goal
    func deleteSavingsGoal(goalId: Int) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await supabase
                .from("savings_goals_table")
                .delete()
                .eq("id", value: goalId)
                .execute()

            Logger.i("GoalsService: Savings goal \(goalId) deleted successfully")
            try await fetchSavingsGoals()
        } catch {
            Logger.e("GoalsService: Failed to delete savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    /// Add a deposit to an existing savings goal
    func addDeposit(goalId: Int, amount: Double) async throws -> SavingsDeposit {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let userId = UserAccount.shared.currentUser?.id else {
            throw BudgetService.BudgetError.noUser
        }

        struct CreateDepositRequest: Codable {
            let goal_id: Int
            let user_id: String
            let amount: Double
        }

        let body = CreateDepositRequest(
            goal_id: goalId,
            user_id: userId,
            amount: amount
        )

        do {
            let deposit: SavingsDeposit = try await supabase
                .from("savings_deposits_table")
                .insert(body)
                .select("*")
                .single()
                .execute()
                .value

            Logger.i("GoalsService: Deposit of $\(amount) added successfully")
            try await fetchSavingsGoals()
            return deposit
        } catch {
            Logger.e("GoalsService: Failed to add deposit: \(error)")
            self.error = error
            throw error
        }
    }
}
