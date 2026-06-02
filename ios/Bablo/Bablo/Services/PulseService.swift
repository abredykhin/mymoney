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
    let comparisonLabel: String

    init(
        startDate: String,
        endDate: String,
        totalIn: Double,
        totalOut: Double,
        spentDeltaFromPrevious: Double?,
        comparisonLabel: String = "vs last period"
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalIn = totalIn
        self.totalOut = totalOut
        self.spentDeltaFromPrevious = spentDeltaFromPrevious
        self.comparisonLabel = comparisonLabel
    }

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
        if abs(spentDeltaFromPrevious) < 0.005 { return "flat \(comparisonLabel)" }
        return "\(Self.signedCurrency(spentDeltaFromPrevious, maximumFractionDigits: 0)) \(comparisonLabel)"
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

    @Published var categoryBreakdown: [CategoryBreakdownItem]?
    @Published var isLoadingBreakdown = false
    @Published var categoryBreakdownError: Error?

    @Published var dailyEnergy: [DailyEnergyItem] = []
    @Published var isLoadingDailyEnergy = false
    @Published var dailyEnergyError: Error?

    @Published var topMerchants: [TopMerchantItem] = []
    @Published var isLoadingTopMerchants = false
    @Published var topMerchantsError: Error?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Fetches the Pulse damage report from account-type-aware daily transaction stats.
    func fetchDamageReport(
        startDate: String,
        endDate: String,
        comparisonStartDate: String? = nil,
        comparisonEndDate: String? = nil,
        comparisonLabel: String = "vs last period"
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
                spentDeltaFromPrevious: previousOut.map { current.totalOut - $0 },
                comparisonLabel: comparisonLabel
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

    // MARK: - Category Breakdown

    func fetchCategoryBreakdown(
        startDate: String,
        endDate: String,
        comparisonStartDate: String? = nil,
        comparisonEndDate: String? = nil,
        trackedCategories: Set<FlexibleSpendingCategory>,
        includePreviousOnly: Bool = false
    ) async throws {
        isLoadingBreakdown = true
        categoryBreakdownError = nil
        defer { isLoadingBreakdown = false }

        Logger.d("PulseService: Fetching category breakdown (\(startDate) to \(endDate))")

        do {
            let current = try await fetchTransactionsForBreakdown(startDate: startDate, endDate: endDate)

            var previous: [BreakdownTransaction] = []
            if let compStart = comparisonStartDate, let compEnd = comparisonEndDate {
                previous = try await fetchTransactionsForBreakdown(startDate: compStart, endDate: compEnd)
            }

            categoryBreakdown = CategoryBreakdownBuilder.build(
                currentTransactions: current,
                previousTransactions: previous,
                trackedCategories: trackedCategories,
                includePreviousOnly: includePreviousOnly
            )

            Logger.i("PulseService: Loaded category breakdown (\(categoryBreakdown?.count ?? 0) buckets)")
        } catch {
            categoryBreakdownError = error
            Logger.e("PulseService: Failed to fetch category breakdown: \(error)")
            throw error
        }
    }

    private func fetchTransactionsForBreakdown(startDate: String, endDate: String) async throws -> [BreakdownTransaction] {
        return try await supabase
            .from("transactions")
            .select("amount, name, date, authorized_date, spend_date, type, personal_finance_category, personal_finance_subcategory, is_spend, is_income")
            .gte("spend_date", value: startDate)
            .lte("spend_date", value: endDate)
            .eq("is_spend", value: true)
            .execute()
            .value
    }

    // MARK: - Daily Energy

    func fetchDailyEnergy(startDate: String, endDate: String) async {
        isLoadingDailyEnergy = true
        dailyEnergyError = nil
        defer { isLoadingDailyEnergy = false }

        struct Params: Encodable {
            let week_start: String
            let week_end: String
        }

        do {
            let energy: [DailyEnergyItem] = try await supabase
                .rpc("get_pulse_weekly_energy", params: Params(week_start: startDate, week_end: endDate))
                .execute()
                .value
            dailyEnergy = energy
            Logger.i("PulseService: Loaded \(energy.count) daily energy items")
        } catch {
            dailyEnergyError = error
            Logger.e("PulseService: Failed to fetch daily energy: \(error)")
        }
    }

    // MARK: - Top Merchants

    func fetchTopMerchants(startDate: String, endDate: String, limit: Int = 5) async {
        isLoadingTopMerchants = true
        topMerchantsError = nil
        defer { isLoadingTopMerchants = false }

        struct Params: Encodable {
            let start_date: String
            let end_date: String
            let lim: Int
        }

        do {
            let merchants: [TopMerchantItem] = try await supabase
                .rpc("get_pulse_top_merchants", params: Params(start_date: startDate, end_date: endDate, lim: limit))
                .execute()
                .value
            topMerchants = merchants
            Logger.i("PulseService: Loaded \(merchants.count) top merchants")
        } catch {
            topMerchantsError = error
            Logger.e("PulseService: Failed to fetch top merchants: \(error)")
        }
    }

    /// Resets all published data and errors to their default/empty/nil states.
    func clearData() {
        damageReport = nil
        categoryBreakdown = nil
        dailyEnergy = []
        topMerchants = []
        damageReportError = nil
        categoryBreakdownError = nil
        dailyEnergyError = nil
        topMerchantsError = nil
    }
}

struct BreakdownTransaction: Codable {
    let amount: Double
    let name: String?
    let date: String?
    let authorizedDate: String?
    var spendDate: String? = nil
    let accountType: String?
    let personal_finance_category: String?
    let personal_finance_subcategory: String?
    let isSpend: Bool
    let isIncome: Bool

    func isInEffectiveDateWindow(startDate: String, endDate: String) -> Bool {
        guard let effectiveDate = spendDate ?? authorizedDate ?? date else { return true }
        return effectiveDate >= startDate && effectiveDate <= endDate
    }

    enum CodingKeys: String, CodingKey {
        case amount
        case name
        case date
        case authorizedDate = "authorized_date"
        case spendDate = "spend_date"
        case accountType = "type"
        case personal_finance_category
        case personal_finance_subcategory
        case isSpend = "is_spend"
        case isIncome = "is_income"
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
