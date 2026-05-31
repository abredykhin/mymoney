import SwiftUI

@MainActor
struct PulseTabView: View {
    @StateObject private var pulseService: PulseService
    @State private var selectedPeriod: PulsePeriod = .week
    @State private var isShowingAllMerchants = false

    @Environment(\.babloTheme) private var theme
    @EnvironmentObject private var userAccount: UserAccount
    @EnvironmentObject private var navigationState: NavigationState

    private let loadsData: Bool

    init(loadsData: Bool = true) {
        self._pulseService = StateObject(wrappedValue: PulseService())
        self.loadsData = loadsData
    }

    init(pulseService: PulseService, loadsData: Bool = false) {
        self._pulseService = StateObject(wrappedValue: pulseService)
        self.loadsData = loadsData
    }

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HomeTopBarView(
                    dateRangeLabel: selectedPeriod.topBarLabel,
                    titleText: "Pulse",
                    actionSystemName: "gearshape",
                    actionAccessibilityLabel: "Settings"
                )

                DamageReportCard(
                    report: pulseService.damageReport,
                    isLoading: pulseService.isLoadingDamageReport,
                    error: pulseService.damageReportError,
                    selectedPeriod: $selectedPeriod,
                    retry: {
                        Task {
                            await loadDamageReport()
                        }
                    }
                )
                .padding(.horizontal, theme.metrics.screenPadding)

                WhereItWentWidgetView(
                    items: pulseService.categoryBreakdown ?? [],
                    isLoading: pulseService.isLoadingBreakdown,
                    error: pulseService.categoryBreakdownError,
                    retry: { Task { await loadBreakdown() } },
                    onItemTapped: { item in
                        let current = selectedPeriod.currentWindow
                        let title = item.bucket.displayName
                        let initialFilter: TransactionFilterValue
                        switch item.bucket {
                        case .category(let cat):
                            initialFilter = .category(cat)
                        case .rest:
                            initialFilter = .other
                        }
                        navigationState.pulseNavPath.append(
                            PulseDestination.transactions(
                                startDate: current.startDate,
                                endDate: current.endDate,
                                title: title,
                                initialFilter: initialFilter,
                                initialMerchantName: nil
                            )
                        )
                    }
                )
                .padding(.horizontal, theme.metrics.screenPadding)

                DailyEnergyWidgetView(
                    items: pulseService.dailyEnergy,
                    period: selectedPeriod.heroPeriod,
                    isLoading: pulseService.isLoadingDailyEnergy,
                    error: pulseService.dailyEnergyError,
                    retry: { Task { await loadDailyEnergy() } },
                    onBarTapped: { startDate, endDate, title in
                        navigationState.pulseNavPath.append(
                            PulseDestination.transactions(startDate: startDate, endDate: endDate, title: title)
                        )
                    }
                )
                .padding(.horizontal, theme.metrics.screenPadding)
                
                TheLineupWidgetView(
                    items: pulseService.topMerchants,
                    totalSpentOfPeriod: pulseService.damageReport?.totalOut,
                    isLoading: pulseService.isLoadingTopMerchants,
                    error: pulseService.topMerchantsError,
                    retry: { Task { await loadTopMerchants() } },
                    onAllTapped: { isShowingAllMerchants = true },
                    onItemTapped: { item in
                        let current = selectedPeriod.currentWindow
                        navigationState.pulseNavPath.append(
                            PulseDestination.transactions(
                                startDate: current.startDate,
                                endDate: current.endDate,
                                title: item.merchantName,
                                initialFilter: .all,
                                initialMerchantName: item.merchantName
                            )
                        )
                    }
                )
                .padding(.horizontal, theme.metrics.screenPadding)
            }
            .padding(.bottom, 96)
        }
        .babloScreenBackground()
        .task(id: selectedPeriod) {
            guard loadsData else { return }
            async let damageReport: () = loadDamageReport()
            async let breakdown: () = loadBreakdown()
            async let energy: () = loadDailyEnergy()
            async let merchants: () = loadTopMerchants()
            _ = await (damageReport, breakdown, energy, merchants)
        }
        .onChange(of: trackedCategories) { _, _ in
            guard loadsData else { return }
            Task { await loadBreakdown() }
        }
        .refreshable {
            guard loadsData else { return }
            async let damageReport: () = loadDamageReport()
            async let breakdown: () = loadBreakdown()
            async let energy: () = loadDailyEnergy()
            async let merchants: () = loadTopMerchants()
            _ = await (damageReport, breakdown, energy, merchants)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PulseDestination.self) { destination in
            switch destination {
            case .transactions(let startDate, let endDate, let title, let initialFilter, let initialMerchantName):
                AllTransactionsView(
                    startDate: startDate,
                    endDate: endDate,
                    title: title,
                    initialFilter: initialFilter,
                    initialMerchantName: initialMerchantName
                )
            }
        }
        .sheet(isPresented: $isShowingAllMerchants) {
            AllMerchantsSheetView(
                pulseService: pulseService,
                initialPeriod: selectedPeriod,
                dismissAction: { isShowingAllMerchants = false }
            )
            .presentationDetents([PresentationDetent.fraction(0.85), PresentationDetent.large])
            .presentationDragIndicator(Visibility.visible)
        }
    }

    private func loadDamageReport() async {
        let current = selectedPeriod.currentWindow
        let comparison = selectedPeriod.comparisonWindow

        do {
            try await pulseService.fetchDamageReport(
                startDate: current.startDate,
                endDate: current.endDate,
                comparisonStartDate: comparison?.startDate,
                comparisonEndDate: comparison?.endDate,
                comparisonLabel: selectedPeriod.comparisonLabel
            )
        } catch {
            // PulseService owns the published error state.
        }
    }

    private func loadBreakdown() async {
        let current = selectedPeriod.currentWindow
        let comparison = selectedPeriod.comparisonWindow

        do {
            try await pulseService.fetchCategoryBreakdown(
                startDate: current.startDate,
                endDate: current.endDate,
                comparisonStartDate: comparison?.startDate,
                comparisonEndDate: comparison?.endDate,
                trackedCategories: trackedCategories
            )
        } catch {
            // PulseService owns the published error state.
        }
    }

    private func loadDailyEnergy() async {
        let window: PulseDateWindow
        switch selectedPeriod {
        case .month:
            window = monthlyEnergyWindow
        case .week:
            window = weeklyEnergyWindow
        case .day:
            window = selectedPeriod.currentWindow
        }
        await pulseService.fetchDailyEnergy(startDate: window.startDate, endDate: window.endDate)
    }

    private var weeklyEnergyWindow: PulseDateWindow {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let start = cal.date(byAdding: .weekOfYear, value: -4, to: thisWeekStart) ?? now
        return PulseDateWindow(startDate: fmt.string(from: start), endDate: fmt.string(from: now))
    }

    private var monthlyEnergyWindow: PulseDateWindow {
        let cal = Calendar.bablo
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
        let start = cal.date(byAdding: .month, value: -2, to: thisMonthStart) ?? now
        return PulseDateWindow(startDate: fmt.string(from: start), endDate: fmt.string(from: now))
    }

    private func loadTopMerchants() async {
        let current = selectedPeriod.currentWindow
        await pulseService.fetchTopMerchants(startDate: current.startDate, endDate: current.endDate)
    }
}

private struct DamageReportCard: View {
    let report: PulseDamageReport?
    let isLoading: Bool
    let error: Error?
    @Binding var selectedPeriod: PulsePeriod
    let retry: () -> Void

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            cardTop
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)

            Divider()
                .background(theme.colors.line.color)

            HStack(spacing: 0) {
                SummaryCell(label: "In", value: report?.formattedIn ?? placeholderAmount)
                Divider()
                SummaryCell(label: "Out", value: report?.formattedOut ?? placeholderAmount)
                Divider()
                SummaryCell(label: "Net", value: report?.formattedNet ?? placeholderAmount, isPositive: (report?.net ?? 0) >= 0)
            }
            .frame(height: 70)
        }
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color, lineWidth: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)
        }
        .shadow(color: theme.effects.isPopArt ? theme.effects.shadowColor : theme.effects.shadowColor.opacity(0.05), radius: theme.effects.shadowRadius, x: theme.effects.shadowX, y: theme.effects.shadowY)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pulse.damageReport")
    }

    private var cardTop: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                BabloSegmentedControl(
                    items: PulsePeriod.allCases.map { .init(id: $0, title: $0.shortTitle) },
                    selection: $selectedPeriod,
                    size: .compact
                )

                Spacer(minLength: 12)

                if let delta = report?.formattedSpentDelta {
                    DeltaBadge(text: delta)
                }
            }

            VStack(spacing: 4) {
                Text("Damage report")
                    .font(theme.typography.mono(size: 12, weight: .bold))
                    .tracking(theme.typography.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.colors.textTertiary.color)

                if isLoading && report == nil {
                    ProgressView()
                        .tint(theme.colors.textPrimary.color)
                        .frame(height: 84)
                } else if error != nil && report == nil {
                    Button(action: retry) {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(theme.typography.body(size: 16, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 84)
                } else {
                    Text(report?.formattedSpent ?? "$0.00")
                        .font(theme.typography.display(size: theme.effects.isPopArt ? 50 : 52, weight: .heavy))
                        .tracking(theme.effects.isPopArt ? theme.typography.displayTracking : 0)
                        .monospacedDigit()
                        .minimumScaleFactor(0.42)
                        .lineLimit(1)
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .modifier(PulseConditionalItalic(isEnabled: theme.effects.isPopArt))
                        .frame(maxWidth: .infinity, minHeight: 60)
                }

                Text("spent \(selectedPeriod.subtitleSuffix)")
                    .font(theme.typography.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
    }

    private var placeholderAmount: String {
        "--"
    }
}

private struct DeltaBadge: View {
    let text: String

    @Environment(\.babloTheme) private var theme

    var body: some View {
        Label(text, systemImage: "bolt.fill")
            .font(theme.typography.body(size: 12, weight: .bold))
            .foregroundStyle(theme.colors.accentDeep.color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.effects.isPopArt ? theme.colors.accent.color : theme.colors.surface.color)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
    }
}

private struct SummaryCell: View {
    let label: String
    let value: String
    var isPositive: Bool? = nil

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(theme.typography.mono(size: 12, weight: .bold))
                .tracking(theme.typography.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.colors.textTertiary.color)

            Text(value)
                .font(theme.typography.body(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background(isPositive == true && theme.effects.isPopArt ? theme.colors.accent.color : .clear)
    }

    private var valueColor: Color {
        guard let isPositive else { return theme.colors.textPrimary.color }
        return isPositive ? theme.colors.accentDeep.color : theme.colors.danger.color
    }
}

enum PulsePeriod: String, CaseIterable, Hashable {
    case day
    case week
    case month

    var shortTitle: String {
        switch self {
        case .day: return "Day"
        case .week: return "Wk"
        case .month: return "Mo"
        }
    }

    var subtitleSuffix: String {
        switch self {
        case .day: return "today"
        case .week: return "this week"
        case .month: return "this month"
        }
    }

    var comparisonLabel: String {
        switch self {
        case .day:   return "vs yesterday"
        case .week:  return "vs last wk"
        case .month: return "vs last mo"
        }
    }

    var topBarLabel: String {
        switch self {
        case .day:   return topBarDateLabel(for: .day)
        case .week:  return topBarDateLabel(for: .week)
        case .month: return topBarDateLabel(for: .month)
        }
    }

    var currentWindow: PulseDateWindow {
        currentWindow(calendar: .bablo)
    }

    var comparisonWindow: PulseDateWindow? {
        comparisonWindow(calendar: .bablo)
    }

    func currentWindow(calendar: Calendar = .bablo) -> PulseDateWindow {
        PulseDateWindow.current(period: self, calendar: calendar)
    }

    func comparisonWindow(calendar: Calendar = .bablo) -> PulseDateWindow? {
        PulseDateWindow.previous(period: self, relativeTo: currentWindow(calendar: calendar), calendar: calendar)
    }

    var heroPeriod: HeroPeriod {
        switch self {
        case .day:   return .day
        case .week:  return .week
        case .month: return .month
        }
    }
}

enum PulseDestination: Hashable {
    case transactions(
        startDate: String,
        endDate: String,
        title: String,
        initialFilter: TransactionFilterValue? = nil,
        initialMerchantName: String? = nil
    )
}

struct PulseDateWindow {
    let startDate: String
    let endDate: String

    static func current(period: PulsePeriod, now: Date = Date(), calendar: Calendar = .bablo) -> PulseDateWindow {
        let cal = calendar
        let end = now
        let start: Date

        switch period {
        case .day:
            start = end
        case .week:
            start = cal.dateInterval(of: .weekOfYear, for: end)?.start ?? end
        case .month:
            let components = cal.dateComponents([.year, .month], from: end)
            start = cal.date(from: components) ?? end
        }

        return make(start: start, end: end, calendar: cal)
    }

    static func previous(period: PulsePeriod, relativeTo current: PulseDateWindow, calendar: Calendar = .bablo) -> PulseDateWindow? {
        let cal = calendar
        let fmt = dateFormatter(calendar: cal)

        guard
            let start = fmt.date(from: current.startDate),
            let end = fmt.date(from: current.endDate)
        else { return nil }

        let previousStart: Date?
        let previousEnd: Date?

        switch period {
        case .day:
            previousStart = cal.date(byAdding: .day, value: -1, to: start)
            previousEnd = cal.date(byAdding: .day, value: -1, to: end)
        case .week:
            previousStart = cal.date(byAdding: .day, value: -7, to: start)
            previousEnd = cal.date(byAdding: .day, value: -7, to: end)
        case .month:
            previousStart = cal.date(byAdding: .month, value: -1, to: start)
            previousEnd = cal.date(byAdding: .day, value: -1, to: start)
        }

        guard let previousStart, let previousEnd else { return nil }
        return make(start: previousStart, end: previousEnd, calendar: cal)
    }

    private static func make(start: Date, end: Date, calendar: Calendar) -> PulseDateWindow {
        let fmt = dateFormatter(calendar: calendar)
        return PulseDateWindow(
            startDate: fmt.string(from: start),
            endDate: fmt.string(from: end)
        )
    }

    private static func dateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter
    }
}

private struct PulseConditionalItalic: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.italic()
        } else {
            content
        }
    }
}

private enum PulsePreviewFixtures {
    @MainActor
    static func emptyService() -> PulseService {
        let service = PulseService()
        service.damageReport = PulseDamageReport(
            startDate: "2026-05-18",
            endDate: "2026-05-24",
            totalIn: 0,
            totalOut: 0,
            spentDeltaFromPrevious: nil
        )
        return service
    }

    @MainActor
    static func dataService() -> PulseService {
        let service = PulseService()
        service.damageReport = PulseDamageReport(
            startDate: "2026-05-13",
            endDate: "2026-05-19",
            totalIn: 612,
            totalOut: 387.42,
            spentDeltaFromPrevious: 76
        )
        service.categoryBreakdown = [
            CategoryBreakdownItem(bucket: .category(.eatsOut), totalAmount: 142, transactionCount: 11,
                                  percentOfTotal: 0.37, previousAmount: 103),
            CategoryBreakdownItem(bucket: .category(.gettingAround), totalAmount: 68, transactionCount: 7,
                                  percentOfTotal: 0.18, previousAmount: 74),
            CategoryBreakdownItem(bucket: .category(.fun), totalAmount: 55, transactionCount: 4,
                                  percentOfTotal: 0.14, previousAmount: 49),
            CategoryBreakdownItem(bucket: .category(.shopping), totalAmount: 48, transactionCount: 3,
                                  percentOfTotal: 0.12, previousAmount: 22),
            CategoryBreakdownItem(bucket: .rest, totalAmount: 74, transactionCount: 5,
                                  percentOfTotal: 0.19, previousAmount: nil),
        ]
        service.topMerchants = [
            TopMerchantItem(merchantName: "Blue Bottle Coffee", totalSpent: 124, transactionCount: 6, personalFinanceCategory: "FOOD_AND_DRINK"),
            TopMerchantItem(merchantName: "Trader Joe's", totalSpent: 98, transactionCount: 3, personalFinanceCategory: "FOOD_AND_DRINK"),
            TopMerchantItem(merchantName: "Lyft", totalSpent: 71, transactionCount: 4, personalFinanceCategory: "TRANSPORTATION"),
            TopMerchantItem(merchantName: "Steam", totalSpent: 59, transactionCount: 2, personalFinanceCategory: "ENTERTAINMENT"),
            TopMerchantItem(merchantName: "Sweetgreen", totalSpent: 44, transactionCount: 3, personalFinanceCategory: "FOOD_AND_DRINK"),
        ]
        return service
    }

    @MainActor
    static func largeAmountService() -> PulseService {
        let service = PulseService()
        service.damageReport = PulseDamageReport(
            startDate: "2026-05-01",
            endDate: "2026-05-24",
            totalIn: 145_000,
            totalOut: 100_000,
            spentDeltaFromPrevious: nil
        )
        return service
    }

    @MainActor
    static func user() -> UserAccount {
        let user = UserAccount.shared
        user.currentUser = User(id: "1", name: "Mia", token: "", email: "mia@example.com")
        return user
    }
}

private struct PulsePreviewShell: View {
    let themeMode: BabloTheme
    let service: PulseService

    var body: some View {
        PulseTabView(pulseService: service, loadsData: false)
            .environmentObject(PulsePreviewFixtures.user())
            .environmentObject(NavigationState())
            .babloTheme(themeMode)
    }
}

#Preview("Pulse Empty · Plain") {
    PulsePreviewShell(themeMode: .normal, service: PulsePreviewFixtures.emptyService())
}

#Preview("Pulse Data · Plain") {
    PulsePreviewShell(themeMode: .normal, service: PulsePreviewFixtures.dataService())
}

#Preview("Pulse Empty · Pop") {
    PulsePreviewShell(themeMode: .pop, service: PulsePreviewFixtures.emptyService())
}

#Preview("Pulse Data · Pop") {
    PulsePreviewShell(themeMode: .pop, service: PulsePreviewFixtures.dataService())
}

#Preview("Pulse Large Amount · Plain") {
    PulsePreviewShell(themeMode: .normal, service: PulsePreviewFixtures.largeAmountService())
}
