import Foundation

// MARK: - SpendingBucket

/// A display bucket for category breakdown — either a recognized flexible category
/// or a catch-all "Rest" for spending that doesn't fit any tracked category.
enum SpendingBucket: Equatable, Hashable {
    case category(FlexibleSpendingCategory)
    case rest
    /// Recurring / mandatory bills (rent, matched mandatory streams). Only produced by
    /// the total-spend Where-it-went breakdown; never appears in the discretionary
    /// Cushion breakdown (which is sourced from variable_transactions).
    case bills

    var id: String {
        switch self {
        case .category(let cat): return cat.rawValue
        case .rest: return "rest"
        case .bills: return "bills"
        }
    }
}

// MARK: - CategoryBreakdownItem

struct CategoryBreakdownItem: Equatable, Identifiable {
    let bucket: SpendingBucket
    let totalAmount: Double
    let transactionCount: Int
    let percentOfTotal: Double
    let previousAmount: Double?

    var id: String { bucket.id }

    /// Percentage change vs previous period. Nil when no previous data.
    var trendPercent: Double? {
        guard let prev = previousAmount, prev > 0.001 else { return nil }
        return (totalAmount - prev) / prev
    }

    /// True = spending went up, false = down, nil = flat (< 1%) or no previous data.
    var isTrendUp: Bool? {
        guard let pct = trendPercent, abs(pct) >= 0.01 else { return nil }
        return pct > 0
    }

    var formattedTrend: String? {
        guard let pct = trendPercent else { return nil }
        if abs(pct) < 0.01 { return "flat" }
        return "\(pct > 0 ? "▲" : "▼") \(Int((abs(pct) * 100).rounded()))%"
    }

    var formattedAmount: String {
        totalAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - CategorySortOrder

enum CategorySortOrder: String, CaseIterable, Identifiable {
    case amount   = "Amount"
    case count    = "Count"
    case trending = "Trending"

    var id: String { rawValue }
}

// MARK: - CategoryBreakdownBuilder

enum CategoryBreakdownBuilder {
    /// Build a breakdown from raw transaction arrays.
    ///
    /// - Parameters:
    ///   - currentTransactions: Transactions for the primary date window.
    ///   - previousTransactions: Transactions for the comparison window (may be empty).
    ///   - trackedCategories: Categories the user chose during onboarding. When empty,
    ///     all recognized Plaid categories are shown individually (no "Rest" merge).
    ///
    /// Results are sorted by amount descending, with the "Rest" bucket always last.
    static func build(
        currentTransactions: [BreakdownTransaction],
        previousTransactions: [BreakdownTransaction] = [],
        trackedCategories: Set<FlexibleSpendingCategory>,
        includePreviousOnly: Bool = false,
        startDate: String? = nil,
        endDate: String? = nil
    ) -> [CategoryBreakdownItem] {
        let filteredCurrent = currentTransactions.filter {
            isSpendingTransaction($0)
                && isInWindow($0, startDate: startDate, endDate: endDate)
        }
        let filteredPrevious = previousTransactions.filter {
            isSpendingTransaction($0)
                && isInWindow($0, startDate: startDate, endDate: endDate)
        }

        let showIndividually: (FlexibleSpendingCategory) -> Bool = trackedCategories.isEmpty
            ? { _ in true }
            : { trackedCategories.contains($0) }

        // Accumulate current period
        var currentMap: [SpendingBucket: (amount: Double, count: Int)] = [:]
        for txn in filteredCurrent {
            let bkt = bucket(for: txn, showIndividually: showIndividually)
            var acc = currentMap[bkt] ?? (0, 0)
            acc.amount += txn.amount
            acc.count  += 1
            currentMap[bkt] = acc
        }

        // Accumulate previous period (same bucket logic)
        var previousMap: [SpendingBucket: Double] = [:]
        for txn in filteredPrevious {
            let bkt = bucket(for: txn, showIndividually: showIndividually)
            previousMap[bkt, default: 0] += txn.amount
        }

        let total = currentMap.values.reduce(0.0) { $0 + $1.amount }

        var items: [CategoryBreakdownItem] = currentMap.map { bkt, acc in
            CategoryBreakdownItem(
                bucket: bkt,
                totalAmount: acc.amount,
                transactionCount: acc.count,
                percentOfTotal: total > 0 ? acc.amount / total : 0,
                previousAmount: previousMap[bkt]
            )
        }

        if includePreviousOnly {
            for (bkt, previousAmount) in previousMap where currentMap[bkt] == nil {
                items.append(
                    CategoryBreakdownItem(
                        bucket: bkt,
                        totalAmount: 0,
                        transactionCount: 0,
                        percentOfTotal: 0,
                        previousAmount: previousAmount
                    )
                )
            }
        }

        // Sort discretionary categories by amount descending; the two catch-all buckets
        // are pinned at the end — Bills (obligations) then Rest (leftover discretionary).
        let bills   = items.filter { $0.bucket == .bills }
        let rest    = items.filter { $0.bucket == .rest }
        var regular = items.filter { $0.bucket != .rest && $0.bucket != .bills }
        regular.sort { $0.totalAmount > $1.totalAmount }
        items = regular + bills + rest

        return items
    }

    // MARK: - Private helpers

    private static func isSpendingTransaction(_ txn: BreakdownTransaction) -> Bool {
        txn.isSpend
    }

    private static func isInWindow(
        _ txn: BreakdownTransaction,
        startDate: String?,
        endDate: String?
    ) -> Bool {
        guard let startDate, let endDate else { return true }
        return txn.isInEffectiveDateWindow(startDate: startDate, endDate: endDate)
    }

    private static func bucket(
        for txn: BreakdownTransaction,
        showIndividually: (FlexibleSpendingCategory) -> Bool
    ) -> SpendingBucket {
        // Recurring / mandatory bills get their own bucket regardless of category, so the
        // total-spend breakdown keeps obligations visible and separate from discretionary
        // spend. (Only populated by the total fetch; discretionary rows are never mandatory.)
        if txn.isMandatory == true {
            return .bills
        }
        if let cat = FlexibleSpendingCategory.map(
            primary: txn.personal_finance_category,
            detailed: txn.personal_finance_subcategory
        ), showIndividually(cat) {
            return .category(cat)
        }
        return .rest
    }
}
