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
    let color: String
    let priority: Int
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
        case color
        case priority
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

// MARK: - Goals Summary Models

struct GoalsSummary: Codable, Equatable {
    let totalStashed: Double
    let totalTarget: Double
    let fundedPct: Double
    let goalCount: Int
    let thisMonth: Double
    let depositoryBalance: Double
    let vaultCovered: Bool
    let goals: [GoalSummaryItem]

    enum CodingKeys: String, CodingKey {
        case totalStashed = "total_stashed"
        case totalTarget = "total_target"
        case fundedPct = "funded_pct"
        case goalCount = "goal_count"
        case thisMonth = "this_month"
        case depositoryBalance = "depository_balance"
        case vaultCovered = "vault_covered"
        case goals
    }
}

struct GoalSummaryItem: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let categoryIcon: String
    let targetAmount: Double
    let currentAmount: Double
    let etaDate: String?
    let isActive: Bool
    let color: String
    let priority: Int
    let pct: Double
    let weeklyRate: Double
    let thisMonth: Double
    let statusLabel: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case categoryIcon = "category_icon"
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case etaDate = "eta_date"
        case isActive = "is_active"
        case color
        case priority
        case pct
        case weeklyRate = "weekly_rate"
        case thisMonth = "this_month"
        case statusLabel = "status_label"
    }

    var progressPercent: Double { min(1.0, max(0.0, pct / 100.0)) }
    var isFunded: Bool { statusLabel == "funded" }
}

// MARK: - Service

@MainActor
class GoalsService: ObservableObject {
    @Published var savingsGoals: [SavingsGoal] = []
    @Published var summary: GoalsSummary?
    @Published var isLoading: Bool = false
    @Published var isSummaryLoading: Bool = false
    @Published var error: Error?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    // MARK: - Summary (primary data source for GoalsTabView)

    /// Fetch vault summary + per-goal analytics via server-side RPC
    func fetchGoalsSummary() async throws {
        isSummaryLoading = true
        error = nil
        defer { isSummaryLoading = false }

        do {
            let result: GoalsSummary = try await supabase
                .rpc("get_goals_summary")
                .execute()
                .value

            self.summary = result
            Logger.i("GoalsService: Summary loaded — \(result.goalCount) goals, stashed $\(result.totalStashed)")
        } catch {
            Logger.e("GoalsService: Failed to fetch goals summary: \(error)")
            self.error = error
            throw error
        }
    }

    // MARK: - CRUD

    /// Fetch all active savings goals for the user (used by tests and detail sheet)
    func fetchSavingsGoals() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let goals: [SavingsGoal] = try await supabase
                .from("savings_goals_table")
                .select("*")
                .eq("is_active", value: true)
                .order("priority", ascending: true)
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
    func createSavingsGoal(
        name: String,
        targetAmount: Double,
        etaDate: String?,
        categoryIcon: String = "✈️",
        color: String = "#A9F236",
        priority: Int = 0
    ) async throws -> SavingsGoal {
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
            let color: String
            let priority: Int
        }

        let body = CreateGoalRequest(
            user_id: userId,
            name: name,
            target_amount: targetAmount,
            eta_date: etaDate,
            category_icon: categoryIcon,
            color: color,
            priority: priority
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
            try await fetchGoalsSummary()
            return goal
        } catch {
            Logger.e("GoalsService: Failed to create savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    /// Update an existing savings goal's editable fields
    func updateSavingsGoal(
        id: Int,
        name: String,
        targetAmount: Double,
        etaDate: String?,
        categoryIcon: String,
        color: String
    ) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        struct UpdateGoalRequest: Codable {
            let name: String
            let target_amount: Double
            let eta_date: String?
            let category_icon: String
            let color: String
        }

        let body = UpdateGoalRequest(
            name: name,
            target_amount: targetAmount,
            eta_date: etaDate,
            category_icon: categoryIcon,
            color: color
        )

        do {
            try await supabase
                .from("savings_goals_table")
                .update(body)
                .eq("id", value: id)
                .execute()

            Logger.i("GoalsService: Goal \(id) updated successfully")
            try await fetchGoalsSummary()
        } catch {
            Logger.e("GoalsService: Failed to update savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    /// Soft-delete (archive) a savings goal
    func archiveSavingsGoal(goalId: Int) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await supabase
                .from("savings_goals_table")
                .update(["is_active": false])
                .eq("id", value: goalId)
                .execute()

            Logger.i("GoalsService: Savings goal \(goalId) archived successfully")
            try await fetchGoalsSummary()
        } catch {
            Logger.e("GoalsService: Failed to archive savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    /// Hard-delete a savings goal (cascades deposits)
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
            try await fetchGoalsSummary()
        } catch {
            Logger.e("GoalsService: Failed to delete savings goal: \(error)")
            self.error = error
            throw error
        }
    }

    // MARK: - Deposits

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
            try await fetchGoalsSummary()
            return deposit
        } catch {
            Logger.e("GoalsService: Failed to add deposit: \(error)")
            self.error = error
            throw error
        }
    }

    /// Fetch deposit history for a specific goal
    func fetchDeposits(goalId: Int) async throws -> [SavingsDeposit] {
        do {
            let deposits: [SavingsDeposit] = try await supabase
                .from("savings_deposits_table")
                .select("*")
                .eq("goal_id", value: goalId)
                .order("deposit_date", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value

            Logger.i("GoalsService: Loaded \(deposits.count) deposits for goal \(goalId)")
            return deposits
        } catch {
            Logger.e("GoalsService: Failed to fetch deposits: \(error)")
            throw error
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        savingsGoals = []
        summary = nil
        error = nil
        Logger.d("GoalsService: Cleared cache")
    }
}
