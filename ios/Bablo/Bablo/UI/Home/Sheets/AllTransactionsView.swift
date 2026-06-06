import SwiftUI

struct AllTransactionsView: View {
    let startDate: String?
    let endDate: String?
    let customTitle: String?
    let initialFilter: TransactionFilterValue?
    let initialMerchantName: String?
    let initialTotalAmount: Double?
    let initialTransactionCount: Int?
    /// When true (Pulse Where-it-went drill-down), bills get their own chip and the
    /// Out/Other/category filters exclude mandatory bills so each bucket reconciles to
    /// its breakdown row. Default false keeps the Home activity sheet byte-for-byte
    /// unchanged.
    let showBillsBucket: Bool

    init(
        startDate: String? = nil,
        endDate: String? = nil,
        title: String? = nil,
        initialFilter: TransactionFilterValue? = nil,
        initialMerchantName: String? = nil,
        initialTotalAmount: Double? = nil,
        initialTransactionCount: Int? = nil,
        showBillsBucket: Bool = false
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.customTitle = title
        self.initialFilter = initialFilter
        self.initialMerchantName = initialMerchantName
        self.initialTotalAmount = initialTotalAmount
        self.initialTransactionCount = initialTransactionCount
        self.showBillsBucket = showBillsBucket
        
        self._searchQuery = State(initialValue: initialMerchantName ?? "")
        
        if let initialFilter {
            self._selectedFilter = State(initialValue: initialFilter)
        } else if startDate != nil && endDate != nil {
            self._selectedFilter = State(initialValue: .out)
        } else {
            self._selectedFilter = State(initialValue: .all)
        }
    }

    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userAccount: UserAccount
    @EnvironmentObject private var accountsService: AccountsService

    @StateObject private var sheetTransactionsService = TransactionsService()
    
    // Search, Filter & Sort State
    @State private var searchQuery: String
    @State private var selectedFilter: TransactionFilterValue
    @State private var selectedSort: TransactionSortOption = .newestFirst
    @State private var isLoading = false
    @State private var isPaginationLoading = false
    @State private var selectedTransaction: Transaction?

    // Onboarding tracked categories
    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        BabloListSheet(
            categoryLabel: isPopArt ? "ACTIVITY" : "Activity",
            title: customTitle ?? "All activity",
            subtitle: subtitleText,
            searchPlaceholder: "Search transactions",
            searchQuery: $searchQuery,
            filterChips: filterChips,
            selectedFilter: $selectedFilter,
            sortOptions: TransactionSortOption.allCases.map { BabloSortOption(id: $0, title: $0.title) },
            selectedSort: $selectedSort,
            resultsCountLabel: isUsingInitialValues ? "\(initialTransactionCount ?? displayTotalCount) RESULTS" : "\(displayTotalCount) RESULTS",
            dismissAction: { dismiss() },
            showDragHandle: false,
            showCloseButton: false,
            showBackButton: true
        ) {
            if isLoading {
                ProgressView()
                    .tint(theme.colors.textPrimary.color)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if processedTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                    Text("No transactions match your search")
                        .font(theme.typography.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 16) {
                    if selectedSort == .highestAmount {
                        VStack(spacing: 0) {
                            ForEach(processedTransactions) { txn in
                                Button {
                                    selectedTransaction = txn
                                } label: {
                                    TransactionSheetRow(transaction: txn, showDate: true)
                                }
                                .buttonStyle(.plain)
                                
                                if txn.id != processedTransactions.last?.id {
                                    Divider()
                                        .overlay(theme.colors.line.color.opacity(0.6))
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(theme.colors.surface.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                                .stroke(
                                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                                )
                        }
                        .shadow(
                            color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.02),
                            radius: isPopArt ? 0 : 8,
                            x: isPopArt ? 3 : 0,
                            y: isPopArt ? 3 : 3
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    } else {
                        ForEach(groupTransactions(processedTransactions)) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Date Group Header
                                HStack(alignment: .lastTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.title)
                                            .font(theme.typography.mono(size: 11, weight: .bold))
                                            .tracking(theme.typography.labelTracking)
                                            .foregroundStyle(theme.colors.textPrimary.color)
                                        
                                        if let subtitle = group.subtitle {
                                            Text(subtitle)
                                                .font(theme.typography.body(size: 11, weight: .semibold))
                                                .foregroundStyle(theme.colors.textSecondary.color)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Daily Net Totals
                                    HStack(spacing: 8) {
                                        let incomes = group.transactions.filter { $0.isIncome }.reduce(0.0) { $0 + $1.absoluteAmount }
                                        let spends = group.transactions.filter { $0.isSpend }.reduce(0.0) { $0 + $1.absoluteAmount }
                                        
                                        if incomes > 0 {
                                            Text("+\(formatIntAmount(incomes))")
                                                .foregroundStyle(theme.colors.success.color)
                                        }
                                        if spends > 0 {
                                            Text("-\(formatIntAmount(spends))")
                                                .foregroundStyle(theme.colors.textPrimary.color)
                                        }
                                    }
                                    .font(theme.typography.body(size: 13, weight: .bold))
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                
                                // Transactions list under the header
                                VStack(spacing: 0) {
                                    ForEach(group.transactions) { txn in
                                        Button {
                                            selectedTransaction = txn
                                        } label: {
                                            TransactionSheetRow(transaction: txn)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if txn.id != group.transactions.last?.id {
                                            Divider()
                                                .overlay(theme.colors.line.color.opacity(0.6))
                                                .padding(.leading, 52)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .background(theme.colors.surface.color)
                                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                                        .stroke(
                                            isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                                            lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                                        )
                                }
                                .shadow(
                                    color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.02),
                                    radius: isPopArt ? 0 : 8,
                                    x: isPopArt ? 3 : 0,
                                    y: isPopArt ? 3 : 3
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Infinite scrolling loader
                    if sheetTransactionsService.paginationInfo?.hasMore == true {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(theme.colors.textPrimary.color)
                                .onAppear {
                                    guard !sheetTransactionsService.isLoading && !isPaginationLoading else { return }
                                    Task {
                                        isPaginationLoading = true
                                        let filter = TransactionFilter(startDate: computedStartDate, endDate: computedEndDate)
                                        try? await sheetTransactionsService.loadMore(
                                            filter: filter,
                                            sortColumn: sortColumn,
                                            sortAscending: sortAscending
                                        )
                                        isPaginationLoading = false
                                    }
                                }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .babloScreenBackground()
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailSheet(transaction: txn) { updated in
                selectedTransaction = updated
                sheetTransactionsService.replaceTransaction(updated)
            }
                .environmentObject(sheetTransactionsService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            isLoading = true
            let options = FetchOptions(
                limit: 100,
                filter: TransactionFilter(startDate: computedStartDate, endDate: computedEndDate, onlySpendOrIncome: showBillsBucket),
                sortColumn: sortColumn,
                sortAscending: sortAscending
            )
            try? await sheetTransactionsService.fetchTransactions(options: options)
            isLoading = false
        }
        .onChange(of: selectedSort) { _, newSort in
            Task {
                isLoading = true
                sheetTransactionsService.clearCache()
                let options = FetchOptions(
                    limit: 100,
                    filter: TransactionFilter(startDate: computedStartDate, endDate: computedEndDate, onlySpendOrIncome: showBillsBucket),
                    sortColumn: sortColumn,
                    sortAscending: sortAscending
                )
                try? await sheetTransactionsService.fetchTransactions(options: options)
                isLoading = false
            }
        }
    }

    // MARK: - Subcomputeds

    private var computedStartDate: String? {
        if let startDate { return startDate }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: thirtyDaysAgo)
    }

    private var computedEndDate: String? {
        if let endDate { return endDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private var sortColumn: String? {
        switch selectedSort {
        case .newestFirst, .oldestFirst:
            return "spend_date"
        case .highestAmount:
            return "amount"
        }
    }

    private var sortAscending: Bool? {
        switch selectedSort {
        case .newestFirst:
            return false
        case .oldestFirst:
            return true
        case .highestAmount:
            return false
        }
    }

    private var isUsingInitialValues: Bool {
        searchQuery.isEmpty &&
        selectedFilter == (initialFilter ?? (startDate != nil && endDate != nil ? .out : .all)) &&
        initialTotalAmount != nil
    }

    /// Best known total count: use server pagination count when available,
    /// falling back to the currently loaded transaction count.
    private var displayTotalCount: Int {
        if let initialTransactionCount, isUsingInitialValues {
            return initialTransactionCount
        }
        return sheetTransactionsService.paginationInfo?.totalCount ?? processedTransactions.count
    }

    private var subtitleText: String {
        let totalCount = isUsingInitialValues ? (initialTransactionCount ?? displayTotalCount) : displayTotalCount
        guard totalCount > 0 else { return "0 txns" }

        return "\(totalCount) txns · \(metricLabel) \(netAmountText) · last \(dateRangeText)"
    }

    /// The Damage-report hero drill-down: the whole period (`.all`, no single merchant),
    /// which shows both inflow and outflow — so its figure is a true net, and the hero
    /// passes `initialTotalAmount` as the signed net (out − in).
    private var isPeriodNetView: Bool {
        selectedFilter == .all && initialMerchantName == nil && startDate != nil
    }

    /// Label the subtitle figure honestly: "net" for the whole-period view (and the
    /// computed-from-rows fallback), "in" for income, "spent" for one-sided spend totals
    /// (Out / a category / Bills / a merchant).
    private var metricLabel: String {
        if isPeriodNetView { return "net" }
        guard isUsingInitialValues, initialTotalAmount != nil else { return "net" }
        return selectedFilter == .income ? "in" : "spent"
    }

    private var netAmountText: String {
        let sum: Double
        if isUsingInitialValues, let initialTotalAmount {
            if isPeriodNetView {
                // Signed net (out − in) straight from the damage report; positive = net outflow.
                sum = initialTotalAmount
            } else if selectedFilter == .income {
                sum = -abs(initialTotalAmount)
            } else {
                sum = abs(initialTotalAmount)
            }
        } else {
            sum = processedTransactions.reduce(0.0) { $0 + $1.amount }
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        
        let formatted = formatter.string(from: NSNumber(value: abs(sum))) ?? "$0"
        if sum > 0 {
            return "-\(formatted)"
        } else if sum < 0 {
            return "+\(formatted)"
        } else {
            return formatted
        }
    }

    private var dateRangeText: String {
        let dates = processedTransactions.compactMap { txn -> Date? in
            let raw = txn.spend_date ?? txn.authorized_date ?? txn.date
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            parser.locale = Locale(identifier: "en_US_POSIX")
            return parser.date(from: raw)
        }
        
        guard !dates.isEmpty else { return "" }
        
        let minDate = dates.min()!
        let maxDate = dates.max()!
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: minDate, to: maxDate)
        let days = (components.day ?? 0) + 1
        
        if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }

    private var filterChips: [BabloFilterChip<TransactionFilterValue>] {
        var chips: [BabloFilterChip<TransactionFilterValue>] = []
        let allTxns = sheetTransactionsService.transactions
        
        // 1. All chip
        chips.append(BabloFilterChip(
            id: .all,
            title: "All",
            count: allTxns.count
        ))
        
        // 2. Out chip
        let outCount = allTxns.filter { $0.isSpend }.count
        chips.append(BabloFilterChip(
            id: .out,
            title: "Out",
            count: outCount
        ))
        
        // 3. In chip
        let inCount = allTxns.filter { $0.isIncome }.count
        chips.append(BabloFilterChip(
            id: .income,
            title: "In",
            count: inCount
        ))
        
        // When showing the Bills bucket (Pulse drill-down), bills are pulled out of the
        // category/Other chips so each chip reconciles to its Where-it-went row. Off by
        // default → Home chips are unchanged.
        let excludeMandatory = showBillsBucket

        // 4. Onboarding tracked categories (Eats, Transit, etc.)
        for category in FlexibleSpendingCategory.allCases {
            guard trackedCategories.contains(category) else { continue }

            let count = allTxns.filter { txn in
                if excludeMandatory && txn.isMandatory { return false }
                return FlexibleSpendingCategory.map(primary: txn.personal_finance_category, detailed: txn.personal_finance_subcategory) == category
            }.count

            if count > 0 {
                chips.append(BabloFilterChip(
                    id: .category(category),
                    title: category.shortName,
                    count: count
                ))
            }
        }

        // 5. Other chip for non-tracked discretionary spending
        let otherCount = allTxns.filter { txn in
            guard txn.isSpend else { return false }
            if excludeMandatory && txn.isMandatory { return false }
            let mapped = FlexibleSpendingCategory.map(primary: txn.personal_finance_category, detailed: txn.personal_finance_subcategory)
            return mapped == nil || !trackedCategories.contains(mapped!)
        }.count

        if otherCount > 0 {
            chips.append(BabloFilterChip(
                id: .other,
                title: "Other",
                count: otherCount
            ))
        }

        // 6. Bills chip (Pulse drill-down only) — recurring/mandatory obligations.
        if showBillsBucket {
            let billsCount = allTxns.filter { $0.isSpend && $0.isMandatory }.count
            if billsCount > 0 {
                chips.append(BabloFilterChip(
                    id: .bills,
                    title: "Bills",
                    count: billsCount
                ))
            }
        }

        return chips
    }

    private var processedTransactions: [Transaction] {
        // Exclude ignored transactions (neither spend nor income)
        var txns = sheetTransactionsService.transactions.filter { $0.isSpend || $0.isIncome }
        
        // 1. Filter by Search Query
        if !searchQuery.isEmpty {
            txns = txns.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.personalFinanceCategory?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        
        // 2. Filter by Category Chip
        // When showBillsBucket (Pulse drill-down), category/Other exclude mandatory bills
        // so each drill-down reconciles to its Where-it-went row. Off by default → Home
        // filtering is unchanged.
        let excludeMandatory = showBillsBucket
        switch selectedFilter {
        case .all:
            break
        case .out:
            txns = txns.filter { $0.isSpend }
        case .income:
            txns = txns.filter { $0.isIncome }
        case .category(let targetCat):
            txns = txns.filter { txn in
                if excludeMandatory && txn.isMandatory { return false }
                return FlexibleSpendingCategory.map(primary: txn.personal_finance_category, detailed: txn.personal_finance_subcategory) == targetCat
            }
        case .other:
            txns = txns.filter { txn in
                guard txn.isSpend else { return false }
                if excludeMandatory && txn.isMandatory { return false }
                let mapped = FlexibleSpendingCategory.map(primary: txn.personal_finance_category, detailed: txn.personal_finance_subcategory)
                return mapped == nil || !trackedCategories.contains(mapped!)
            }
        case .bills:
            txns = txns.filter { $0.isSpend && $0.isMandatory }
        }
        
        // 3. Sort Order
        switch selectedSort {
        case .newestFirst:
            txns.sort { $0.spendDate > $1.spendDate }
        case .oldestFirst:
            txns.sort { $0.spendDate < $1.spendDate }
        case .highestAmount:
            txns.sort { $0.absoluteAmount > $1.absoluteAmount }
        }
        
        return txns
    }

    // MARK: - Helpers

    private func groupTransactions(_ txns: [Transaction]) -> [TransactionGroup] {
        let grouped = Dictionary(grouping: txns) { txn -> String in
            txn.spend_date ?? txn.authorized_date ?? txn.date
        }
        
        let sortedKeys: [String]
        switch selectedSort {
        case .newestFirst:
            sortedKeys = grouped.keys.sorted(by: >)
        case .oldestFirst:
            sortedKeys = grouped.keys.sorted(by: <)
        case .highestAmount:
            sortedKeys = grouped.keys.sorted { date1, date2 in
                let max1 = grouped[date1]?.map(\.absoluteAmount).max() ?? 0
                let max2 = grouped[date2]?.map(\.absoluteAmount).max() ?? 0
                return max1 > max2
            }
        }
        
        let todayStr = formatDateString(Date())
        let yesterdayStr = formatDateString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        
        return sortedKeys.map { key in
            var groupTxns = grouped[key] ?? []
            
            // Sort individual transactions within each group according to selection
            switch selectedSort {
            case .newestFirst:
                groupTxns.sort { $0.spendDate > $1.spendDate }
            case .oldestFirst:
                groupTxns.sort { $0.spendDate < $1.spendDate }
            case .highestAmount:
                groupTxns.sort { $0.absoluteAmount > $1.absoluteAmount }
            }
            
            var title = ""
            var subtitle: String? = nil
            
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            parser.locale = Locale(identifier: "en_US_POSIX")
            
            if key == todayStr {
                title = "TODAY"
                if let date = parser.date(from: key) {
                    subtitle = formatGroupSubtitle(date)
                }
            } else if key == yesterdayStr {
                title = "YESTERDAY"
                if let date = parser.date(from: key) {
                    subtitle = formatGroupSubtitle(date)
                }
            } else {
                if let date = parser.date(from: key) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEEE"
                    title = formatter.string(from: date).uppercased()
                    subtitle = formatGroupSubtitle(date)
                } else {
                    title = key
                }
            }
            
            return TransactionGroup(
                id: key,
                title: title,
                subtitle: subtitle,
                transactions: groupTxns
            )
        }
    }

    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func formatGroupSubtitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatIntAmount(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: val)) ?? "$\(Int(val.rounded()))"
    }
}

// MARK: - Transaction Group Helper

struct TransactionGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let transactions: [Transaction]
}

// MARK: - Transaction Row Subview

struct TransactionSheetRow: View {
    let transaction: Transaction
    var showDate: Bool = false
    
    @Environment(\.babloTheme) private var theme
    @EnvironmentObject private var accountsService: AccountsService
    
    private var amountColor: Color {
        if transaction.isSpend {
            return theme.colors.textPrimary.color
        } else if transaction.isIncome {
            return theme.colors.accentDeep.color
        } else {
            return theme.colors.textSecondary.color
        }
    }
    
    private var presentation: RecentTransactionPresentation {
        RecentTransactionPresentation(transaction: transaction)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 36, height: 36)
                
                if presentation.usesSystemIcon {
                    Image(systemName: presentation.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                } else {
                    Text(presentation.iconName)
                        .font(.system(size: 17))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    Text(transaction.truncatedDisplayName)
                        .font(theme.typography.body(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(1)
                    
                    Text(categoryTagText.uppercased())
                        .font(theme.typography.mono(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(categoryTagForeground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryTagBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                Text(rowSubtitle)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(presentation.amountText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if transaction.pending {
                    Text("pending")
                        .font(theme.typography.body(size: 10, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    private var categoryTagText: String {
        if let cat = transaction.personal_finance_category, cat.contains("SPLIT") || cat.contains("REFUND") {
            return "SPLIT REFUND"
        }
        if transaction.isActualTransfer {
            return "TRANSFER"
        }
        if let cat = FlexibleSpendingCategory.map(primary: transaction.personal_finance_category, detailed: transaction.personal_finance_subcategory) {
            return cat.shortName
        }
        return presentation.categoryText
    }

    private var categoryTagBackground: Color {
        if let cat = FlexibleSpendingCategory.map(primary: transaction.personal_finance_category, detailed: transaction.personal_finance_subcategory) {
            return cat.barColor.opacity(0.12)
        }
        return theme.colors.surfaceMuted.color
    }

    private var categoryTagForeground: Color {
        if let cat = FlexibleSpendingCategory.map(primary: transaction.personal_finance_category, detailed: transaction.personal_finance_subcategory) {
            return cat.barColor
        }
        return theme.colors.textSecondary.color
    }
    
    private var rowSubtitle: String {
        let account = lookupAccount(id: transaction.account_id)
        let bank = lookupBank(accountId: transaction.account_id)
        
        let dateStr: String
        if showDate {
            let rawDate = transaction.spend_date ?? transaction.authorized_date ?? transaction.date
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            parser.locale = Locale(identifier: "en_US_POSIX")
            if let date = parser.date(from: rawDate) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                dateStr = formatter.string(from: date)
            } else {
                dateStr = rawDate
            }
        } else {
            dateStr = ""
        }
        
        let timeStr = formatTransactionTime(transaction.created_at ?? "")
        
        let accountDetails: String
        if let bank = bank, let account = account {
            accountDetails = "\(bank.name) ·\(account.mask ?? "")"
        } else if let account = account {
            accountDetails = account.displayName
        } else {
            accountDetails = "Account ..\(transaction.account_id)"
        }
        
        var parts: [String] = []
        if !dateStr.isEmpty {
            parts.append(dateStr)
        }
        if !timeStr.isEmpty {
            parts.append(timeStr)
        }
        parts.append(accountDetails)
        
        return parts.joined(separator: " · ")
    }
    
    private func lookupAccount(id: Int) -> BankAccount? {
        for bank in accountsService.banksWithAccounts {
            if let account = bank.accounts.first(where: { $0.id == id }) {
                return account
            }
        }
        return nil
    }
    
    private func lookupBank(accountId: Int) -> Bank? {
        return accountsService.banksWithAccounts.first(where: { bank in
            bank.accounts.contains(where: { $0.id == accountId })
        })
    }
    
    private func formatTransactionTime(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        var parsedDate: Date? = nil
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: raw) {
                parsedDate = d
                break
            }
        }
        
        if parsedDate == nil {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            parsedDate = isoFormatter.date(from: raw)
        }
        
        if parsedDate == nil {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            parsedDate = isoFormatter.date(from: raw)
        }
        
        guard let date = parsedDate else { return "" }
        
        let output = DateFormatter()
        output.dateFormat = "h:mm a"
        output.timeZone = TimeZone.current
        return output.string(from: date)
    }
}

// MARK: - Local Sorting Enum

enum TransactionSortOption: String, CaseIterable, Identifiable {
    case newestFirst = "newest_first"
    case oldestFirst = "oldest_first"
    case highestAmount = "highest_amount"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        case .highestAmount: return "Highest amount"
        }
    }
}

// MARK: - Category Color Extension

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

// MARK: - Dynamic Filtering Chip Value

enum TransactionFilterValue: Hashable {
    case all
    case out
    case income
    case category(FlexibleSpendingCategory)
    case other
    /// Recurring / mandatory bills. Only surfaced when the sheet is opened with
    /// `showBillsBucket` (the Pulse Where-it-went drill-down).
    case bills
}
