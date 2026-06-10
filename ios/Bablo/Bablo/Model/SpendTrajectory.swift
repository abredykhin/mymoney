import Foundation

// MARK: - SpendTrajectoryRow (raw RPC row)

/// One aggregated `(primary, subcategory)` row returned by the `get_spend_trajectory` RPC.
/// The server intentionally returns Plaid-category granularity and lets the client regroup
/// with `FlexibleSpendingCategory.map` — the same mapping the rest of the app uses — so there
/// is a single source of truth for category bucketing.
struct SpendTrajectoryRow: Decodable, Equatable {
    let primaryCategory: String?
    let subcategory: String?
    let mtdSpent: Double
    let trailingAvgMonthly: Double
    let txnCountMtd: Int

    enum CodingKeys: String, CodingKey {
        case primaryCategory     = "primary_category"
        case subcategory         = "subcategory"
        case mtdSpent            = "mtd_spent"
        case trailingAvgMonthly  = "trailing_avg_monthly"
        case txnCountMtd         = "txn_count_mtd"
    }
}

// MARK: - SpendTrajectoryItem (per-bucket projection)

/// Projected month-end burn for a single discretionary bucket.
struct SpendTrajectoryItem: Identifiable, Equatable {
    let bucket: SpendingBucket
    /// Money already spent in this bucket this month.
    let mtdSpent: Double
    /// Trailing monthly average for this bucket (the established habit rate).
    let monthlyAverage: Double
    let txnCountMtd: Int

    var id: String { bucket.id }

    /// Where this bucket lands by month-end if the habit continues: the larger of what's
    /// already spent and the historical monthly rate. Anchoring on the historical total
    /// (rather than naive linear extrapolation) is what makes a lumpy merchant like Amazon
    /// project to ~$3,000 from a $500 start instead of a misleading ~$1,666.
    var projectedMonthEnd: Double { max(mtdSpent, monthlyAverage) }

    /// Expected *future* burn for the rest of the month (never negative).
    var projectedRemaining: Double { max(0, projectedMonthEnd - mtdSpent) }

    var label: String {
        switch bucket {
        case .category(let cat): return cat.shortName
        case .bills:             return "Bills"
        case .rest:              return "Other"
        }
    }
}

// MARK: - SpendTrajectory

/// The full month-end projection, built from the raw RPC rows.
struct SpendTrajectory: Equatable {
    /// Per-bucket projections, sorted by projected *remaining* burn (biggest threat first).
    let items: [SpendTrajectoryItem]

    /// Total expected future discretionary burn across all buckets.
    var totalProjectedRemaining: Double {
        items.reduce(0) { $0 + $1.projectedRemaining }
    }

    /// The single bucket about to eat the most of what's left — the headline driver.
    var topDriver: SpendTrajectoryItem? {
        items.first.flatMap { $0.projectedRemaining > 0 ? $0 : nil }
    }

    /// The honest cushion: what's left in the pool after subtracting the burn the user's
    /// established habits are still expected to inflict this month. Can go negative — that
    /// negativity is the whole insight ("$2,000 safe is really ≈ $0").
    func committedSafeToSpend(poolRemaining: Double) -> Double {
        poolRemaining - totalProjectedRemaining
    }

    static let empty = SpendTrajectory(items: [])

    // MARK: Build

    /// Regroup raw `(primary, subcategory)` rows into `FlexibleSpendingCategory` buckets and
    /// compute each bucket's projection. Projection (`max`) is applied at the bucket level —
    /// after summing the sub-pairs — because projecting each pair and summing would not equal
    /// projecting the bucket total.
    static func build(rows: [SpendTrajectoryRow]) -> SpendTrajectory {
        struct Accumulator {
            var mtd: Double = 0
            var avg: Double = 0
            var count: Int = 0
        }

        var byBucket: [SpendingBucket: Accumulator] = [:]

        for row in rows {
            // variable_transactions rows are never mandatory, so a row is either a tracked
            // category or the catch-all "rest" — never the bills bucket.
            let bucket: SpendingBucket
            if let cat = FlexibleSpendingCategory.map(
                primary: row.primaryCategory,
                detailed: row.subcategory
            ) {
                bucket = .category(cat)
            } else {
                bucket = .rest
            }

            var acc = byBucket[bucket] ?? Accumulator()
            acc.mtd   += row.mtdSpent
            acc.avg   += row.trailingAvgMonthly
            acc.count += row.txnCountMtd
            byBucket[bucket] = acc
        }

        let items = byBucket
            .map { bucket, acc in
                SpendTrajectoryItem(
                    bucket: bucket,
                    mtdSpent: acc.mtd,
                    monthlyAverage: acc.avg,
                    txnCountMtd: acc.count
                )
            }
            .sorted { $0.projectedRemaining > $1.projectedRemaining }

        return SpendTrajectory(items: items)
    }
}
