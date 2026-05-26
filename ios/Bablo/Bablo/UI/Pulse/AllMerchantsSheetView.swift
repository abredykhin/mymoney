import SwiftUI

/// Concrete bottom sheet for displaying "All merchants" lineup in the Pulse tab.
struct AllMerchantsSheetView: View {
    @ObservedObject var pulseService: PulseService
    let dismissAction: () -> Void
    
    @Environment(\.babloTheme) private var theme
    
    // Local State
    @State private var selectedPeriod: PulsePeriod
    @State private var searchQuery: String = ""
    @State private var selectedFilter: MerchantFilterValue = .all
    @State private var selectedSort: MerchantSortOption = .spend
    
    @State private var unfilteredItems: [TopMerchantItem] = []
    @State private var isLoading = false
    @State private var error: Error? = nil
    
    init(pulseService: PulseService, initialPeriod: PulsePeriod, dismissAction: @escaping () -> Void) {
        self.pulseService = pulseService
        self._selectedPeriod = State(initialValue: initialPeriod)
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        BabloListSheet(
            categoryLabel: isPopArt ? "THE LINEUP" : "The lineup",
            title: "All merchants",
            subtitle: subtitleText,
            searchPlaceholder: "Search merchants",
            searchQuery: $searchQuery,
            filterChips: filterChips,
            selectedFilter: $selectedFilter,
            sortOptions: MerchantSortOption.allCases.map { BabloSortOption(id: $0, title: $0.title) },
            selectedSort: $selectedSort,
            resultsCountLabel: "\(processedItems.count) RESULTS",
            dismissAction: dismissAction,
            periodSelector: AnyView(periodSelectorView)
        ) {
            if isLoading {
                ProgressView()
                    .tint(theme.colors.textPrimary.color)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if error != nil {
                VStack(spacing: 8) {
                    Text("Couldn't load merchants")
                        .font(theme.typography.body(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                    
                    Button {
                        Task { await loadData() }
                    } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(theme.typography.body(size: 13, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if processedItems.isEmpty {
                Text("No results match your search")
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(processedItems) { item in
                        MerchantSheetRow(
                            item: item,
                            rank: unfilteredItems.firstIndex(of: item).map { $0 + 1 } ?? 1,
                            maxSpent: unfilteredItems.first?.totalSpent ?? 1,
                            theme: theme
                        )
                        
                        Divider()
                            .overlay(theme.colors.line.color.opacity(0.6))
                            .padding(.leading, 56)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .task(id: selectedPeriod) {
            await loadData()
        }
    }
    
    // MARK: - Subviews & Sub-computeds
    
    private var periodSelectorView: some View {
        BabloSegmentedControl(
            items: PulsePeriod.allCases.map { .init(id: $0, title: $0.shortTitle.prefix(1).uppercased()) },
            selection: $selectedPeriod,
            size: .compact
        )
    }
    
    private var subtitleText: String {
        let totalCount = unfilteredItems.count
        let totalSpentSum = unfilteredItems.reduce(0.0) { $0 + $1.totalSpent }
        let spentStr = formatAmount(totalSpentSum)
        return "\(totalCount) merchants · \(spentStr) · \(selectedPeriod.subtitleSuffix)"
    }
    
    private var filterChips: [BabloFilterChip<MerchantFilterValue>] {
        var chips: [BabloFilterChip<MerchantFilterValue>] = []
        
        // Add "All" chip first
        chips.append(BabloFilterChip(
            id: .all,
            title: "All",
            count: unfilteredItems.count
        ))
        
        // Group and count dynamic active categories
        var categoryCounts: [FlexibleSpendingCategory: Int] = [:]
        for item in unfilteredItems {
            if let cat = FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil) {
                categoryCounts[cat, default: 0] += 1
            }
        }
        
        // Sort active categories by raw value (or logical display order)
        let sortedCats = categoryCounts.keys.sorted(by: { $0.rawValue < $1.rawValue })
        for cat in sortedCats {
            chips.append(BabloFilterChip(
                id: .category(cat),
                title: cat.shortName,
                count: categoryCounts[cat]
            ))
        }
        
        return chips
    }
    
    private var processedItems: [TopMerchantItem] {
        var filtered = unfilteredItems
        
        // 1. Filter by Search Query
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.merchantName.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // 2. Filter by Category Chip
        switch selectedFilter {
        case .all:
            break
        case .category(let targetCat):
            filtered = filtered.filter { item in
                let itemCat = FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil)
                return itemCat == targetCat
            }
        }
        
        // 3. Sort Order
        switch selectedSort {
        case .spend:
            filtered.sort { $0.totalSpent > $1.totalSpent }
        case .count:
            filtered.sort { $0.transactionCount > $1.transactionCount }
        case .name:
            filtered.sort { $0.merchantName.localizedCompare($1.merchantName) == .orderedAscending }
        }
        
        return filtered
    }
    
    // MARK: - Private Helpers
    
    private func loadData() async {
        isLoading = true
        error = nil
        
        let window = selectedPeriod.currentWindow
        let client = SupabaseManager.shared.client
        
        struct Params: Encodable {
            let start_date: String
            let end_date: String
            let lim: Int
        }
        
        do {
            let fetched: [TopMerchantItem] = try await client
                .rpc("get_pulse_top_merchants", params: Params(start_date: window.startDate, end_date: window.endDate, lim: 100))
                .execute()
                .value
            
            // Apply updates on MainActor
            self.unfilteredItems = fetched
            self.isLoading = false
            
            // Safe filter adjustment
            if case .category(let cat) = selectedFilter {
                let stillExists = fetched.contains { item in
                    FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil) == cat
                }
                if !stillExists {
                    selectedFilter = .all
                }
            }
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
    
    private func formatAmount(_ amt: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amt)) ?? "$0"
    }
}

// MARK: - Filter and Sort Submodels

enum MerchantFilterValue: Hashable {
    case all
    case category(FlexibleSpendingCategory)
}

enum MerchantSortOption: String, CaseIterable, Identifiable {
    case spend
    case count
    case name
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .spend: return "Spend"
        case .count: return "Transactions"
        case .name: return "Alphabetical"
        }
    }
}

// MARK: - Merchant Row Subview

private struct MerchantSheetRow: View {
    let item: TopMerchantItem
    let rank: Int
    let maxSpent: Double
    let theme: BabloResolvedTheme
    
    private var category: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(primary: item.personalFinanceCategory, detailed: nil)
    }
    
    private var iconEmoji: String {
        category?.emoji ?? String(item.merchantName.prefix(1))
    }
    
    private var iconBackground: Color {
        if let cat = category {
            return cat.barColor.opacity(0.15)
        }
        return theme.colors.surfaceMuted.color
    }
    
    private var barColor: Color {
        rank == 1 ? theme.colors.accent.color : theme.colors.textTertiary.color.opacity(0.35)
    }
    
    private var barFraction: Double {
        guard maxSpent > 0 else { return 0 }
        return item.totalSpent / maxSpent
    }
    
    private var sparklineColor: Color {
        category?.barColor ?? theme.colors.textTertiary.color
    }
    
    private func formatValue(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: val)) ?? "$0"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank (Heavy monospace font)
            Text("\(rank)")
                .font(theme.typography.mono(size: 15, weight: .bold))
                .foregroundStyle(rank == 1 ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)
                .frame(width: 18, alignment: .leading)
            
            // Emoji Category Icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)
                
                Text(iconEmoji)
                    .font(.system(size: 20))
            }
            
            // Name + Relative Progress Bar
            VStack(alignment: .leading, spacing: 5) {
                Text(item.merchantName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                
                GeometryReader { geo in
                    barColor
                        .frame(width: geo.size.width * barFraction, height: 3)
                        .clipShape(Capsule())
                }
                .frame(height: 3)
            }
            
            // Sparkline Trend Curve
            BabloSparklineView(seed: item.merchantName, color: sparklineColor)
                .frame(width: 58, height: 18)
                .padding(.horizontal, 4)
            
            // Amount & Details (1x · category short name)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatValue(item.totalSpent))
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .monospacedDigit()
                
                Text("\(item.transactionCount)x · \(category?.shortName ?? "Other")")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            
            // Chevron arrow right
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.colors.textTertiary.color)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Private Category Color Mappings

private extension FlexibleSpendingCategory {
    var barColor: Color {
        switch self {
        case .eatsOut:       return Color(red: 0.953, green: 0.482, blue: 0.416)
        case .coffeeRuns:    return Color(red: 0.961, green: 0.650, blue: 0.137)
        case .groceries:     return Color(red: 0.365, green: 0.725, blue: 0.365)
        case .fun:           return Color(red: 0.608, green: 0.349, blue: 0.714)
        case .shopping:      return Color(red: 0.914, green: 0.118, blue: 0.549)
        case .gettingAround: return Color(red: 0.290, green: 0.624, blue: 0.890)
        case .selfCare:      return Color(red: 0.969, green: 0.424, blue: 0.620)
        case .travel:        return Color(red: 0.110, green: 0.710, blue: 0.710)
        }
    }
}

// MARK: - Previews

#Preview("All Merchants Sheet · Plain") {
    let service = PulseService()
    service.topMerchants = [
        TopMerchantItem(merchantName: "Concert venue", totalSpent: 65, transactionCount: 1, personalFinanceCategory: "ENTERTAINMENT"),
        TopMerchantItem(merchantName: "Trader Joe's", totalSpent: 42, transactionCount: 1, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Blue Bottle Coffee", totalSpent: 39, transactionCount: 6, personalFinanceCategory: "FOOD_AND_DRINK"),
        TopMerchantItem(merchantName: "Lyft", totalSpent: 35, transactionCount: 4, personalFinanceCategory: "TRANSPORTATION"),
    ]
    return AllMerchantsSheetView(pulseService: service, initialPeriod: .week, dismissAction: {})
        .babloTheme(.normal)
}

#Preview("All Merchants Sheet · Pop") {
    let service = PulseService()
    service.topMerchants = [
        TopMerchantItem(merchantName: "Concert venue", totalSpent: 65, transactionCount: 1, personalFinanceCategory: "ENTERTAINMENT"),
        TopMerchantItem(merchantName: "Trader Joe's", totalSpent: 42, transactionCount: 1, personalFinanceCategory: "FOOD_AND_DRINK"),
    ]
    return AllMerchantsSheetView(pulseService: service, initialPeriod: .week, dismissAction: {})
        .babloTheme(.pop)
}
