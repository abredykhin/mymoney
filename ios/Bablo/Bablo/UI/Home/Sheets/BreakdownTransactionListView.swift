import SwiftUI

// MARK: - Main View

/// Pushed from a tappable step card in MoneyLeftBreakdownView.
/// Shows the pool of transactions that make up that step, and lets the user
/// tap any row to see a detail sheet.
struct BreakdownTransactionListView: View {
    let source: BreakdownTransactionSource
    let period: HeroPeriod
    let categoryFilter: String?
    private let previewTransactions: [Transaction]?

    @EnvironmentObject private var subService: SubscriptionsService
    @EnvironmentObject private var homeBreakdownService: HomeBreakdownService
    @EnvironmentObject private var userAccount: UserAccount
    @Environment(\.babloTheme) private var theme

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var selectedTransaction: Transaction?

    init(
        source: BreakdownTransactionSource,
        period: HeroPeriod,
        categoryFilter: String? = nil,
        previewTransactions: [Transaction]? = nil
    ) {
        self.source = source
        self.period = period
        self.categoryFilter = categoryFilter
        self.previewTransactions = previewTransactions
        _transactions = State(initialValue: previewTransactions ?? [])
    }

    private var obligationStreams: [RecurringStream] {
        subService.allRecurringStreams
            .filter { $0.type == "expense" && $0.isActive && !$0.isExcluded }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    private var trackedCategories: Set<FlexibleSpendingCategory> {
        let rawValues = userAccount.profile?.trackedSpendingCategories ?? []
        return Set(rawValues.compactMap { FlexibleSpendingCategory(rawValue: $0) })
    }

    private func displaySpendBucket(primary: String?, detailed: String?) -> String {
        guard let category = FlexibleSpendingCategory.map(primary: primary, detailed: detailed) else {
            return "Everything else"
        }
        if trackedCategories.isEmpty || trackedCategories.contains(category) {
            return category.displayName
        }
        return "Everything else"
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(theme.colors.textPrimary.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if source == .obligations {
                obligationsContent
            } else if transactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .babloScreenBackground()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(navigationTitle)
                        .font(theme.typography.body(size: 15, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    if let subtitle = navigationSubtitle {
                        Text(subtitle)
                            .font(theme.typography.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailSheet(transaction: txn) { updated in
                selectedTransaction = updated
                if let index = transactions.firstIndex(where: { $0.id == updated.id }) {
                    transactions[index] = updated
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            guard source != .obligations else { return }
            guard previewTransactions == nil else { return }
            isLoading = true
            switch source {
            case .variableSpend:
                let allTxns = await homeBreakdownService.fetchVariableTransactionList(for: period)
                if let filter = categoryFilter {
                    transactions = allTxns.filter { txn in
                        let cat = displaySpendBucket(
                            primary: txn.personal_finance_category,
                            detailed: txn.personal_finance_subcategory
                        )
                        return cat == filter
                    }
                } else {
                    transactions = allTxns
                }
            case .income:
                transactions = await homeBreakdownService.fetchIncomeTransactionList()
            case .obligations:
                break
            }
            isLoading = false
        }
    }

    // MARK: - Sub-views

    private var transactionList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(transactions) { txn in
                    Button {
                        selectedTransaction = txn
                    } label: {
                        TransactionListRow(transaction: txn, theme: theme)
                    }
                    .buttonStyle(.plain)

                    if txn.id != transactions.last?.id {
                        Divider()
                            .overlay(theme.colors.line.color.opacity(0.5))
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.vertical, 8)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var obligationsContent: some View {
        ScrollView(showsIndicators: false) {
            if obligationStreams.isEmpty {
                emptyState
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(obligationStreams) { stream in
                        ObligationStreamRow(stream: stream, theme: theme)

                        if stream.id != obligationStreams.last?.id {
                            Divider()
                                .overlay(theme.colors.line.color.opacity(0.5))
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.vertical, 8)
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                        .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary.color)
            Text("No transactions yet")
                .font(theme.typography.body(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        switch source {
        case .income:       return "Income this month"
        case .obligations:  return "Monthly obligations"
        case .variableSpend:
            switch period {
            case .day:   return "Spent today"
            case .week:  return "Spent this week"
            case .month: return "Spent this month"
            }
        }
    }

    private var navigationSubtitle: String? {
        switch source {
        case .income:
            let total = transactions.reduce(0) { $0 + abs($1.amount) }
            guard total > 0 else { return nil }
            return "$\(Int(total.rounded()).formatted()) total"
        case .obligations:
            let total = obligationStreams.reduce(0) { $0 + $1.monthlyAmount }
            guard total > 0 else { return nil }
            return "$\(Int(total.rounded()).formatted())/mo"
        case .variableSpend:
            let total = transactions.reduce(0) { $0 + abs($1.amount) }
            guard total > 0 else { return nil }
            return "$\(Int(total.rounded()).formatted()) · \(transactions.count) transactions"
        }
    }
}

// MARK: - Transaction row

private struct TransactionListRow: View {
    let transaction: Transaction
    let theme: BabloResolvedTheme

    var body: some View {
        let presentation = RecentTransactionPresentation(transaction: transaction)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 40, height: 40)
                if presentation.usesSystemIcon {
                    Image(systemName: presentation.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                } else {
                    Text(presentation.iconName)
                        .font(.system(size: 18))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.truncatedDisplayName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                Text(formattedDate)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(transaction.isSpend
                        ? theme.colors.textPrimary.color
                        : (transaction.isIncome ? theme.colors.success.color : theme.colors.textSecondary.color))
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

    private var amountText: String {
        let value = transaction.absoluteAmount
        let prefix: String
        if transaction.isSpend { prefix = "-" }
        else if transaction.isIncome { prefix = "+" }
        else { prefix = transaction.amount > 0 ? "-" : "+" }
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "$\(Int(value.rounded()))"
        return "\(prefix)\(formatted)"
    }

    private var formattedDate: String {
        let raw = transaction.spend_date ?? transaction.authorized_date ?? transaction.date
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: raw) else { return raw }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}

// MARK: - Obligation stream row

private struct ObligationStreamRow: View {
    let stream: RecurringStream
    let theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stream.merchantName ?? stream.description)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                Text(stream.frequencyDisplay)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(stream.monthlyAmount.rounded()).formatted())/mo")
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                if let next = stream.predictedNextDate {
                    Text("next \(shortDate(next))")
                        .font(theme.typography.body(size: 10, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func shortDate(_ raw: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: raw) else { return raw }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}

#if DEBUG
#Preview("Breakdown Transactions") {
    NavigationStack {
        BreakdownTransactionListView(
            source: .variableSpend,
            period: .week,
            previewTransactions: BreakdownTransactionListPreviewFixtures.transactions
        )
    }
    .environmentObject(BreakdownTransactionListPreviewFixtures.subService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.homeBreakdownService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.transactionsService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.accountsService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.userAccount)
    .babloTheme(.normal)
}

#Preview("Breakdown Transactions · Empty") {
    NavigationStack {
        BreakdownTransactionListView(
            source: .variableSpend,
            period: .week,
            previewTransactions: []
        )
    }
    .environmentObject(BreakdownTransactionListPreviewFixtures.subService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.homeBreakdownService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.transactionsService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.accountsService)
    .environmentObject(BreakdownTransactionListPreviewFixtures.userAccount)
    .babloTheme(.normal)
}

private enum BreakdownTransactionListPreviewFixtures {
    @MainActor static var transactionsService: TransactionsService {
        let service = TransactionsService()
        service.transactions = transactions
        return service
    }

    @MainActor static var subService: SubscriptionsService {
        SubscriptionsService()
    }

    @MainActor static var homeBreakdownService: HomeBreakdownService {
        HomeBreakdownService()
    }

    @MainActor static var accountsService: AccountsService {
        AccountsService.onboardingPreviewLinkedBank
    }

    @MainActor static var userAccount: UserAccount {
        UserAccount.shared
    }

    static let transactions: [Transaction] = [
        Transaction(
            id: 9001,
            account_id: 3,
            amount: 14.30,
            date: currentDate(offset: 0),
            authorized_date: currentDate(offset: 0),
            name: "LYFT *RIDE",
            merchant_name: "Lyft",
            pending: false,
            category: nil,
            transaction_id: "preview_tx_lyft",
            pending_transaction_transaction_id: nil,
            iso_currency_code: "USD",
            payment_channel: "online",
            user_id: nil,
            logo_url: nil,
            website: "lyft.com",
            personal_finance_category: "TRANSPORTATION",
            personal_finance_subcategory: "TRANSPORTATION_TAXIS_AND_RIDE_SHARES",
            created_at: nil,
            updated_at: nil,
            is_spend: true,
            is_income: false
        ),
        Transaction(
            id: 9002,
            account_id: 3,
            amount: 6.50,
            date: currentDate(offset: -1),
            authorized_date: currentDate(offset: -1),
            name: "BLUE BOTTLE COFFEE",
            merchant_name: "Blue Bottle",
            pending: false,
            category: nil,
            transaction_id: "preview_tx_coffee",
            pending_transaction_transaction_id: nil,
            iso_currency_code: "USD",
            payment_channel: "in store",
            user_id: nil,
            logo_url: nil,
            website: "bluebottlecoffee.com",
            personal_finance_category: "FOOD_AND_DRINK",
            personal_finance_subcategory: "FOOD_AND_DRINK_COFFEE",
            created_at: nil,
            updated_at: nil,
            is_spend: true,
            is_income: false
        ),
        Transaction(
            id: 9003,
            account_id: 1,
            amount: -128.00,
            date: currentDate(offset: -2),
            authorized_date: currentDate(offset: -2),
            name: "ACME PAYROLL",
            merchant_name: "Acme Payroll",
            pending: false,
            category: nil,
            transaction_id: "preview_tx_income",
            pending_transaction_transaction_id: nil,
            iso_currency_code: "USD",
            payment_channel: "other",
            user_id: nil,
            logo_url: nil,
            website: nil,
            personal_finance_category: "INCOME",
            personal_finance_subcategory: "INCOME_WAGES",
            created_at: nil,
            updated_at: nil,
            is_spend: false,
            is_income: true
        )
    ]

    private static func currentDate(offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
#endif
