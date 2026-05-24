import Foundation
import Combine
import Supabase

/// In/out/net rollup for the Pulse damage report.
struct PulseDamageReport: Equatable {
    let startDate: String
    let endDate: String
    let totalIn: Double
    let totalOut: Double
    let spentDeltaFromPrevious: Double?

    var net: Double {
        totalIn - totalOut
    }

    var formattedSpent: String {
        Self.currency(totalOut)
    }

    var formattedIn: String {
        Self.signedCurrency(totalIn, maximumFractionDigits: 0)
    }

    var formattedOut: String {
        "-\(Self.currency(totalOut, maximumFractionDigits: 0))"
    }

    var formattedNet: String {
        Self.signedCurrency(net, maximumFractionDigits: 0)
    }

    var formattedSpentDelta: String? {
        guard let spentDeltaFromPrevious else { return nil }
        if abs(spentDeltaFromPrevious) < 0.005 { return "flat vs last wk" }
        return "\(Self.signedCurrency(spentDeltaFromPrevious, maximumFractionDigits: 0)) vs last wk"
    }

    private static func currency(_ amount: Double, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }

    private static func signedCurrency(_ amount: Double, maximumFractionDigits: Int = 2) -> String {
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(currency(amount, maximumFractionDigits: maximumFractionDigits))"
    }
}

@MainActor
final class PulseService: ObservableObject {
    @Published var damageReport: PulseDamageReport?
    @Published var isLoadingDamageReport = false
    @Published var damageReportError: Error?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetches the Pulse damage report from account-type-aware daily transaction stats.
    func fetchDamageReport(
        startDate: String,
        endDate: String,
        comparisonStartDate: String? = nil,
        comparisonEndDate: String? = nil
    ) async throws {
        isLoadingDamageReport = true
        damageReportError = nil
        defer { isLoadingDamageReport = false }

        Logger.d("PulseService: Fetching damage report (\(startDate) to \(endDate))")

        do {
            let currentStats = try await fetchDailyTransactionStats(startDate: startDate, endDate: endDate)
            let current = Self.aggregateDamageReportRows(currentStats)

            var previousOut: Double?
            if let comparisonStartDate, let comparisonEndDate {
                let comparisonStats = try await fetchDailyTransactionStats(startDate: comparisonStartDate, endDate: comparisonEndDate)
                if !currentStats.isEmpty && !comparisonStats.isEmpty {
                    previousOut = Self.aggregateDamageReportRows(comparisonStats).totalOut
                }
            }

            damageReport = PulseDamageReport(
                startDate: startDate,
                endDate: endDate,
                totalIn: current.totalIn,
                totalOut: current.totalOut,
                spentDeltaFromPrevious: previousOut.map { current.totalOut - $0 }
            )

            Logger.i("PulseService: Loaded damage report in \(current.totalIn), out \(current.totalOut)")
        } catch {
            damageReportError = error
            Logger.e("PulseService: Failed to fetch damage report: \(error)")
            throw error
        }
    }

    private func fetchDailyTransactionStats(startDate: String, endDate: String) async throws -> [DailyTransactionStat] {
        struct Params: Encodable {
            let start_date: String
            let end_date: String
        }

        return try await supabase
            .rpc("get_daily_transaction_stats", params: Params(start_date: startDate, end_date: endDate))
            .execute()
            .value
    }

    private static func aggregateDamageReportRows(_ rows: [DailyTransactionStat]) -> (totalIn: Double, totalOut: Double) {
        rows.reduce(into: (totalIn: 0.0, totalOut: 0.0)) { totals, row in
            totals.totalIn += row.totalIn
            totals.totalOut += row.totalOut
        }
    }
}

private struct DailyTransactionStat: Codable {
    let date: String
    let totalIn: Double
    let totalOut: Double

    enum CodingKeys: String, CodingKey {
        case date
        case totalIn = "total_in"
        case totalOut = "total_out"
    }
}
