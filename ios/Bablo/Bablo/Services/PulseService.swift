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
        abs(amount).formatted(.currency(code: "USD").precision(.fractionLength(maximumFractionDigits)))
    }

    private static func signedCurrency(_ amount: Double, maximumFractionDigits: Int = 2) -> String {
        amount.formatted(.currency(code: "USD").sign(strategy: .always()).precision(.fractionLength(maximumFractionDigits)))
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

    /// Cushion sheet data, sourced from the DISCRETIONARY layer (`variable_transactions`)
    /// over MTD/WTD-aligned windows — kept separate from `categoryBreakdown` (raw `is_spend`,
    /// full-period) so the whole Cushion screen reconciles with the Liquid Hero. See AGENTS.md
    /// "Spend Classification Layers".
    @Published var cushionBreakdown: [CategoryBreakdownItem]?
    @Published var cushionDailySeries: CushionDailySeries?
    @Published var isLoadingCushion = false
    @Published var cushionError: Error?

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
            // TOTAL spend (transactions WHERE is_spend), so the Swing's categories sum to the
            // Damage Report headline. Mandatory bills are not hidden here — the builder routes
            // them into their own `.bills` bucket (via is_mandatory) so they're visible and the
            // total reconciles, while the discretionary hero/Money-Left/Cushion stay on
            // variable_transactions.
            let current = try await fetchTransactionsForBreakdown(from: "transactions", startDate: startDate, endDate: endDate)

            var previous: [BreakdownTransaction] = []
            if let compStart = comparisonStartDate, let compEnd = comparisonEndDate {
                previous = try await fetchTransactionsForBreakdown(from: "transactions", startDate: compStart, endDate: compEnd)
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

    private func fetchTransactionsForBreakdown(from table: String = "transactions", startDate: String, endDate: String) async throws -> [BreakdownTransaction] {
        return try await supabase
            .from(table)
            .select("amount, name, date, authorized_date, spend_date, type, personal_finance_category, personal_finance_subcategory, is_spend, is_income, is_mandatory")
            .gte("spend_date", value: startDate)
            .lte("spend_date", value: endDate)
            .eq("is_spend", value: true)
            .execute()
            .value
    }

    // MARK: - Cushion (discretionary, aligned)

    /// Loads the Cushion sheet's drivers + pace from `variable_transactions` (discretionary spend)
    /// over MTD/WTD-aligned windows. Both windows share one definition of spend so the drivers
    /// reconcile to the Liquid Hero's cushion delta. `previousStart/End` MUST be aligned to the
    /// same elapsed length as the current window (e.g. June 1 vs May 1), never a full prior period.
    func fetchCushionData(
        currentStart: String,
        currentEnd: String,
        previousStart: String,
        previousEnd: String,
        trackedCategories: Set<FlexibleSpendingCategory>
    ) async {
        isLoadingCushion = true
        cushionError = nil
        defer { isLoadingCushion = false }

        do {
            async let currentRowsTask = fetchTransactionsForBreakdown(from: "variable_transactions", startDate: currentStart, endDate: currentEnd)
            async let previousRowsTask = fetchTransactionsForBreakdown(from: "variable_transactions", startDate: previousStart, endDate: previousEnd)
            let (current, previous) = try await (currentRowsTask, previousRowsTask)

            cushionBreakdown = CategoryBreakdownBuilder.build(
                currentTransactions: current,
                previousTransactions: previous,
                trackedCategories: trackedCategories,
                includePreviousOnly: true
            )
            cushionDailySeries = CushionDailySeries(
                current: Self.dailyTotals(current),
                previous: Self.dailyTotals(previous),
                currentStart: currentStart,
                currentEnd: currentEnd,
                previousStart: previousStart,
                previousEnd: previousEnd
            )
            Logger.i("PulseService: Loaded cushion data (\(cushionBreakdown?.count ?? 0) buckets)")
        } catch {
            cushionError = error
            Logger.e("PulseService: Failed to fetch cushion data: \(error)")
        }
    }

    /// Sum of (signed) spend per effective day, sorted ascending. Drives the pace chart.
    private static func dailyTotals(_ rows: [BreakdownTransaction]) -> [CushionDailyPoint] {
        var byDate: [String: Double] = [:]
        for row in rows {
            guard let date = row.spendDate ?? row.authorizedDate ?? row.date else { continue }
            byDate[date, default: 0] += row.amount
        }
        return byDate
            .map { CushionDailyPoint(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
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
        cushionBreakdown = nil
        cushionDailySeries = nil
        dailyEnergy = []
        topMerchants = []
        damageReportError = nil
        categoryBreakdownError = nil
        cushionError = nil
        dailyEnergyError = nil
        topMerchantsError = nil
    }
}

/// One day of (signed) discretionary spend, used to build the Cushion pace chart.
struct CushionDailyPoint: Equatable {
    let date: String   // "yyyy-MM-dd"
    let amount: Double
}

/// Per-day discretionary spend for the current and aligned-previous windows, plus the window
/// bounds so the pace chart can render a gap-free line (days with no spend count as $0).
struct CushionDailySeries: Equatable {
    let current: [CushionDailyPoint]
    let previous: [CushionDailyPoint]
    let currentStart: String
    let currentEnd: String
    let previousStart: String
    let previousEnd: String
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
    /// True when the row is a recurring/mandatory bill (already counted in monthly
    /// obligations). Only meaningful in the total-spend Where-it-went fetch; the
    /// discretionary `variable_transactions` rows the Cushion uses are all false.
    /// Optional so a missing `is_mandatory` column decodes to nil (→ not a bill)
    /// instead of throwing keyNotFound.
    var isMandatory: Bool? = nil

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
        case isMandatory = "is_mandatory"
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
