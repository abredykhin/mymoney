//
//  CatefogorySpendDetail.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/9/25.
//

import Charts
import Foundation
import SwiftUI

// MARK: - Core Data Models

struct Category {
    let id: UUID
    let name: String
    let color: String  // Hex color code
    let icon: String  // SF Symbol name
    let subcategories: [Subcategory]
    let budget: Double?

    init(
        id: UUID = UUID(), name: String, color: String, icon: String,
        subcategories: [Subcategory] = [], budget: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.subcategories = subcategories
        self.budget = budget
    }
}

struct Subcategory {
    let id: UUID
    let name: String
    let icon: String
    let color: String

    init(id: UUID = UUID(), name: String, icon: String, color: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}

struct MonthlySpending {
    let month: String  // "Jan", "Feb", etc.
    let year: Int
    let amount: Double
    let date: Date

    init(month: String, year: Int, amount: Double, date: Date) {
        self.month = month
        self.year = year
        self.amount = amount
        self.date = date
    }
}

struct CategorySpendingData {
    let category: Category
    let currentMonthSpent: Double
    let budgetRemaining: Double?
    let totalSpentThisYear: Double
    let averagePerMonth: Double
    let monthlySpending: [MonthlySpending]
    let recentTransactions: [Transaction]

    var budgetUsedPercentage: Double? {
        guard let budget = category.budget else { return nil }
        return currentMonthSpent / budget
    }

    var isOverBudget: Bool {
        guard let budget = category.budget else { return false }
        return currentMonthSpent > budget
    }
}

// MARK: - Sample Data Generator

extension CategorySpendingData {
    static func sampleFoodAndDrink() -> CategorySpendingData {
        let restaurantsSubcategory = Subcategory(
            name: "RESTAURANTS",
            icon: "🍔",
            color: "#FF6B6B"
        )

        let groceriesSubcategory = Subcategory(
            name: "GROCERIES",
            icon: "🥑",
            color: "#4ECDC4"
        )

        let foodCategory = Category(
            name: "Food & Drink",
            color: "#8B5CF6",
            icon: "fork.knife",
            subcategories: [restaurantsSubcategory, groceriesSubcategory],
            budget: 3175.0
        )

        // Sample monthly spending data (last 12 months)
        let monthlyData: [MonthlySpending] = [
            MonthlySpending(
                month: "Jul", year: 2024, amount: 2100.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 7))!),
            MonthlySpending(
                month: "Aug", year: 2024, amount: 2450.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 8))!),
            MonthlySpending(
                month: "Sep", year: 2024, amount: 2800.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 9))!),
            MonthlySpending(
                month: "Oct", year: 2024, amount: 2650.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 10))!),
            MonthlySpending(
                month: "Nov", year: 2024, amount: 3100.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 11))!),
            MonthlySpending(
                month: "Dec", year: 2024, amount: 3400.0,
                date: Calendar.current.date(from: DateComponents(year: 2024, month: 12))!),
            MonthlySpending(
                month: "Jan", year: 2025, amount: 2800.0,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 1))!),
            MonthlySpending(
                month: "Feb", year: 2025, amount: 2200.0,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 2))!),
            MonthlySpending(
                month: "Mar", year: 2025, amount: 2600.0,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 3))!),
            MonthlySpending(
                month: "Apr", year: 2025, amount: 3200.0,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 4))!),
            MonthlySpending(
                month: "May", year: 2025, amount: 3244.58,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 5))!),
            MonthlySpending(
                month: "Jun", year: 2025, amount: 145.50,
                date: Calendar.current.date(from: DateComponents(year: 2025, month: 6))!),
        ]

        // Sample transactions for recent months
        let sampleTransactions = [
            // June 2025 transactions
            Transaction(
                id: 1,
                account_id: 0,
                amount: 12.50,
                date: "2025-06-01",
                authorized_date: "2025-06-01",
                name: "McDonalds",
                merchant_name: "McDonalds",
                pending: false,
                category: ["Food and Drink", "Restaurants"],
                transaction_id: "1",
                pending_transaction_transaction_id: nil,
                iso_currency_code: "USD",
                payment_channel: "online",
                user_id: nil,
                logo_url: nil,
                website: nil,
                personal_finance_category: "FOOD_AND_DRINK",
                personal_finance_subcategory: "FOOD_AND_DRINK_FAST_FOOD",
                created_at: nil,
                updated_at: nil
            ),

            Transaction(
                id: 2,
                account_id: 0,
                amount: 350.75,
                date: "2024-12-05",
                authorized_date: "2024-12-05",
                name: "Delta Airlines",
                merchant_name: "Delta Airlines",
                pending: true,
                category: ["Travel"],
                transaction_id: "2",
                pending_transaction_transaction_id: nil,
                iso_currency_code: "USD",
                payment_channel: "online",
                user_id: nil,
                logo_url: nil,
                website: nil,
                personal_finance_category: "TRAVEL",
                personal_finance_subcategory: nil,
                created_at: nil,
                updated_at: nil
            ),

            Transaction(
                id: 3,
                account_id: 0,
                amount: -2500.00,  // Negative to show as income
                date: "2024-12-15",
                authorized_date: "2024-12-15",
                name: "ACME Corp Payroll",
                merchant_name: "ACME Corp",
                pending: false,
                category: ["Income", "Payroll"],
                transaction_id: "3",
                pending_transaction_transaction_id: nil,
                iso_currency_code: "USD",
                payment_channel: "other",
                user_id: nil,
                logo_url: nil,
                website: nil,
                personal_finance_category: "INCOME",
                personal_finance_subcategory: nil,
                created_at: nil,
                updated_at: nil
            ),
        ]

        return CategorySpendingData(
            category: foodCategory,
            currentMonthSpent: 145.50,  // June spending so far
            budgetRemaining: 3029.50,  // 3175 - 145.50
            totalSpentThisYear: 14190.08,  // Updated total
            averagePerMonth: 2365.01,  // Updated average
            monthlySpending: monthlyData,
            recentTransactions: sampleTransactions
        )
    }
}

struct CategorySpendDetailView: View {
    let spendingData: CategorySpendingData
    @State private var selectedYear = 2025

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection

                // Budget Status
                budgetStatusSection

                // Spending Chart
                spendingChartSection

                // Key Metrics
                keyMetricsSection

                // Transactions
                transactionsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)  // Bottom padding for tab bar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CATEGORIES")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(spendingData.category.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: spendingData.category.color))

            HStack(spacing: 12) {
                ForEach(spendingData.category.subcategories, id: \.id) { subcategory in
                    SubcategoryPill(subcategory: subcategory)
                }
            }
        }
    }

    // MARK: - Budget Status Section
    private var budgetStatusSection: some View {
        VStack(spacing: 8) {
            Text("SPENT")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text("$\(spendingData.currentMonthSpent, specifier: "%.2f")")
                    .font(.system(size: 48, weight: .medium))

                if spendingData.currentMonthSpent == 0 {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .offset(y: -20)
                }
            }

            if let budgetRemaining = spendingData.budgetRemaining {
                Text("$\(budgetRemaining, specifier: "%.0f") left")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Spending Chart Section
    private var spendingChartSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            HStack {
                Spacer()
                Text("$\(spendingData.category.budget ?? 0, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(12)
            }

            Chart(spendingData.monthlySpending, id: \.month) { monthData in
                BarMark(
                    x: .value("Month", monthData.month),
                    y: .value("Amount", monthData.amount)
                )
                .foregroundStyle(
                    monthData.amount > (spendingData.category.budget ?? Double.infinity)
                        ? .red : .red.opacity(0.7))

                if let budget = spendingData.category.budget {
                    RuleMark(y: .value("Budget", budget))
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let month = value.as(String.self) {
                            Text(month.prefix(1))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("KEY METRICS")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(selectedYear)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 12) {
                MetricRow(
                    title: "Total spend this year",
                    value: String(format: "$%.2f", spendingData.totalSpentThisYear)
                )

                MetricRow(
                    title: "Average per month this year",
                    value: String(format: "$%.2f", spendingData.averagePerMonth)
                )
            }
        }
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("View all") {
                    // Handle view all action
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 24) {
                ForEach(groupedTransactionsByMonth.prefix(3), id: \.month) { monthGroup in
                    TransactionMonthGroup(
                        month: monthGroup.month,
                        transactions: monthGroup.transactions,
                        spendingData: spendingData,
                        emptyMessage: monthGroup.transactions.isEmpty
                            ? "No transactions in \(monthGroup.month)" : nil
                    )
                }
            }
        }
    }

    // Helper to group transactions by month
    private var groupedTransactionsByMonth: [MonthTransactionGroup] {
        // Use UTC calendar for consistency with database date format
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let currentDate = Date()

        let inputDateFormatter = DateFormatter()
        inputDateFormatter.dateFormat = "yyyy-MM-dd"
        inputDateFormatter.timeZone = TimeZone(identifier: "UTC")

        var monthGroups: [MonthTransactionGroup] = []

        for i in 0..<6 {
            let monthDate =
                calendar.date(byAdding: .month, value: -i, to: currentDate) ?? currentDate
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = i == 0 ? "MMMM" : "MMMM"  // Could customize for current month
            monthFormatter.timeZone = TimeZone(identifier: "UTC")

            let monthName = monthFormatter.string(from: monthDate)
            let monthNumber = calendar.component(.month, from: monthDate)
            let year = calendar.component(.year, from: monthDate)

            // Filter transactions for this month
            let monthTransactions = spendingData.recentTransactions.filter { transaction in
                guard let transactionDateObject = inputDateFormatter.date(from: transaction.date)
                else {
                    return false  // Skip if date string is not parsable
                }
                let transactionMonth = calendar.component(.month, from: transactionDateObject)
                let transactionYear = calendar.component(.year, from: transactionDateObject)
                return transactionMonth == monthNumber && transactionYear == year
            }.sorted { t1, t2 in
                guard let date1 = inputDateFormatter.date(from: t1.date),
                    let date2 = inputDateFormatter.date(from: t2.date)
                else {
                    // Fallback for unparseable dates; consider logging or specific handling
                    return
                        (inputDateFormatter.date(from: t1.date) != nil
                        && inputDateFormatter.date(from: t2.date) == nil)
                }
                return date1 > date2  // Sort by date descending
            }

            monthGroups.append(
                MonthTransactionGroup(
                    month: monthName,
                    monthNumber: monthNumber,
                    year: year,
                    transactions: monthTransactions
                ))
        }

        return monthGroups
    }
}

// MARK: - Supporting Views

struct MonthTransactionGroup {
    let month: String
    let monthNumber: Int
    let year: Int
    let transactions: [Transaction]
}

struct SubcategoryPill: View {
    let subcategory: Subcategory

    var body: some View {
        HStack(spacing: 6) {
            Text(subcategory.icon)
                .font(.caption)

            Text(subcategory.name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct TransactionMonthGroup: View {
    let month: String
    let transactions: [Transaction]
    let spendingData: CategorySpendingData
    let emptyMessage: String?

    init(
        month: String, transactions: [Transaction], spendingData: CategorySpendingData,
        emptyMessage: String? = nil
    ) {
        self.month = month
        self.transactions = transactions
        self.spendingData = spendingData
        self.emptyMessage = emptyMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month)
                .font(.title2)
                .fontWeight(.semibold)

            if transactions.isEmpty {
                Text(emptyMessage ?? "No transactions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(transactions, id: \.id) { transaction in
                        TransactionRow(transaction: transaction, spendingData: spendingData)
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let spendingData: CategorySpendingData

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private var subcategoryIcon: String {
        // Find the subcategory for this transaction
        //        if let subcategoryId = transaction.subcategoryId,
        //           let subcategory = spendingData.category.subcategories.first(where: { $0.id == subcategoryId }) {
        //            return subcategory.icon
        //        }
        return "🍽️"  // Default food icon
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)

            //            Text(transaction.description)
            //                .font(.body)
            //                .foregroundColor(.primary)

            Spacer()

            Text(subcategoryIcon)
                .font(.caption)

            Text("$\(transaction.amount, specifier: "%.2f")")
                .font(.body)
                .fontWeight(.medium)

            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct CategorySpendDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CategorySpendDetailView(spendingData: CategorySpendingData.sampleFoodAndDrink())
        }
    }
}
