import SwiftUI

@MainActor
struct PulseTabView: View {
    @StateObject private var pulseService: PulseService
    @State private var selectedPeriod: PulsePeriod = .week

    @Environment(\.babloTheme) private var theme

    private let loadsData: Bool

    init(loadsData: Bool = true) {
        self._pulseService = StateObject(wrappedValue: PulseService())
        self.loadsData = loadsData
    }

    init(pulseService: PulseService, loadsData: Bool = false) {
        self._pulseService = StateObject(wrappedValue: pulseService)
        self.loadsData = loadsData
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
            }
            .padding(.bottom, 96)
        }
        .babloScreenBackground()
        .task(id: selectedPeriod) {
            guard loadsData else { return }
            await loadDamageReport()
        }
        .refreshable {
            guard loadsData else { return }
            await loadDamageReport()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadDamageReport() async {
        let current = selectedPeriod.currentWindow
        let comparison = selectedPeriod.comparisonWindow

        do {
            try await pulseService.fetchDamageReport(
                startDate: current.startDate,
                endDate: current.endDate,
                comparisonStartDate: comparison?.startDate,
                comparisonEndDate: comparison?.endDate
            )
        } catch {
            // PulseService owns the published error state.
        }
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

private enum PulsePeriod: String, CaseIterable, Hashable {
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

    var topBarLabel: String {
        switch self {
        case .day:   return topBarDateLabel(for: .day)
        case .week:  return topBarDateLabel(for: .week)
        case .month: return topBarDateLabel(for: .month)
        }
    }

    var currentWindow: PulseDateWindow {
        PulseDateWindow.current(period: self)
    }

    var comparisonWindow: PulseDateWindow? {
        PulseDateWindow.previous(period: self, relativeTo: currentWindow)
    }
}

private struct PulseDateWindow {
    let startDate: String
    let endDate: String

    static func current(period: PulsePeriod, now: Date = Date()) -> PulseDateWindow {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let end = now
        let start: Date

        switch period {
        case .day:
            start = end
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        case .month:
            let components = calendar.dateComponents([.year, .month], from: end)
            start = calendar.date(from: components) ?? end
        }

        return make(start: start, end: end, calendar: calendar)
    }

    static func previous(period: PulsePeriod, relativeTo current: PulseDateWindow) -> PulseDateWindow? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        guard
            let start = dateFormatter.date(from: current.startDate),
            let end = dateFormatter.date(from: current.endDate)
        else { return nil }

        let previousStart: Date?
        let previousEnd: Date?

        switch period {
        case .day:
            previousStart = calendar.date(byAdding: .day, value: -1, to: start)
            previousEnd = calendar.date(byAdding: .day, value: -1, to: end)
        case .week:
            previousStart = calendar.date(byAdding: .day, value: -7, to: start)
            previousEnd = calendar.date(byAdding: .day, value: -7, to: end)
        case .month:
            previousStart = calendar.date(byAdding: .month, value: -1, to: start)
            previousEnd = calendar.date(byAdding: .day, value: -1, to: start)
        }

        guard let previousStart, let previousEnd else { return nil }
        return make(start: previousStart, end: previousEnd, calendar: calendar)
    }

    private static func make(start: Date, end: Date, calendar: Calendar) -> PulseDateWindow {
        PulseDateWindow(
            startDate: dateFormatter.string(from: start),
            endDate: dateFormatter.string(from: end)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
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
