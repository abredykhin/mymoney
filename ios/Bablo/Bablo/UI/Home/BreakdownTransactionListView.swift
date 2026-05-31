import SwiftUI

// MARK: - Main View

/// Pushed from a tappable step card in MoneyLeftBreakdownView.
/// Shows the pool of transactions that make up that step, and lets the user
/// tap any row to see a detail sheet.
struct BreakdownTransactionListView: View {
    let source: BreakdownTransactionSource
    let period: HeroPeriod
    private let previewTransactions: [Transaction]?

    @EnvironmentObject private var budgetService: BudgetService
    @Environment(\.babloTheme) private var theme

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var selectedTransaction: Transaction?

    init(
        source: BreakdownTransactionSource,
        period: HeroPeriod,
        previewTransactions: [Transaction]? = nil
    ) {
        self.source = source
        self.period = period
        self.previewTransactions = previewTransactions
        _transactions = State(initialValue: previewTransactions ?? [])
    }

    // For obligations we derive the list from already-loaded recurring streams
    private var obligationStreams: [RecurringStream] {
        budgetService.allRecurringStreams
            .filter { $0.type == "expense" && $0.isActive && !$0.isExcluded }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
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
                transactions = await budgetService.fetchVariableTransactionList(for: period)
            case .income:
                transactions = await budgetService.fetchIncomeTransactionList()
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
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            // Name + date
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                Text(formattedDate)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer(minLength: 8)

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(transaction.isSpend ? theme.colors.textPrimary.color : (transaction.isIncome ? theme.colors.success.color : theme.colors.textSecondary.color))
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
        if transaction.isSpend {
            prefix = "-"
        } else if transaction.isIncome {
            prefix = "+"
        } else {
            prefix = transaction.amount > 0 ? "-" : "+"
        }
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

    private var iconName: String {
        if transaction.isActualTransfer { return "arrow.left.arrow.right" }
        let cat = (transaction.personal_finance_category ?? "").lowercased()
        if cat.contains("food") || cat.contains("restaurant") { return "fork.knife" }
        if cat.contains("transport") || cat.contains("travel") { return "car.fill" }
        if cat.contains("shop") || cat.contains("merchandise") { return "bag.fill" }
        if cat.contains("income") || cat.contains("payroll") { return "arrow.down.circle.fill" }
        if cat.contains("transfer") { return "arrow.left.arrow.right" }
        if cat.contains("entertain") || cat.contains("recreation") { return "gamecontroller.fill" }
        if cat.contains("health") || cat.contains("medical") { return "cross.fill" }
        if cat.contains("bill") || cat.contains("utilities") { return "bolt.fill" }
        return "creditcard.fill"
    }
}

// MARK: - Obligation stream row

private struct ObligationStreamRow: View {
    let stream: RecurringStream
    let theme: BabloResolvedTheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.iconCornerRadius, style: .continuous)
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            // Name + frequency
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

            // Monthly equivalent
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

// MARK: - Transaction detail sheet

struct MerchantSpendPresentation: Equatable {
    let transactionCountThisWeek: Int
    let totalSpentThisWeek: Double

    var summaryText: String {
        guard transactionCountThisWeek > 0 else { return "No spend this week" }
        return "\(transactionCountThisWeek)x spend this week"
    }

    var amountText: String {
        NumberFormatter.currency.string(from: NSNumber(value: totalSpentThisWeek)) ?? "$0"
    }
}

struct TransactionDetailDatePresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    let rows: [Row]

    init(transaction: Transaction) {
        let value = Self.authorizedDateTime(for: transaction) ??
            Self.formatTransactionDate(transaction.spend_date ?? transaction.authorized_date ?? transaction.date, style: .long)
        rows = [Row(label: "Authorized", value: value)]
    }

    private static func authorizedDateTime(for transaction: Transaction) -> String? {
        guard let raw = transaction.authorized_date, !raw.isEmpty else { return nil }
        if raw.contains("T"), let date = parsedDateTime(raw) {
            return formatDateTime(date, dateFormat: "EEE, MMM d · h:mm a")
        }
        return formatTransactionDate(raw, style: .long)
    }

    private static func formatTransactionDate(_ raw: String, style: DateFormatter.Style) -> String {
        guard let date = parsedDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatDateTime(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private static func parsedDate(_ raw: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")

        if raw.count >= 10 {
            parser.dateFormat = "yyyy-MM-dd"
            if let date = parser.date(from: String(raw.prefix(10))) {
                return date
            }
        }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private static func parsedDateTime(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: raw)
    }
}

struct TransactionDetailSheet: View {
    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountsService: AccountsService
    @EnvironmentObject private var budgetService: BudgetService
    @EnvironmentObject private var transactionsService: TransactionsService
    @EnvironmentObject private var userAccount: UserAccount

    @State private var transaction: Transaction
    @State private var isCategoryPickerPresented = false
    @State private var selectedCategory: FlexibleSpendingCategory?
    @State private var isSavingCategory = false
    @State private var isCreatingRepeat = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showRepeatFrequencyDialog = false
    @State private var merchantHistoryTransactions: [Transaction] = []
    @State private var hasLoadedMerchantHistory = false

    private let onTransactionChanged: (Transaction) -> Void

    init(transaction: Transaction, onTransactionChanged: @escaping (Transaction) -> Void = { _ in }) {
        _transaction = State(initialValue: transaction)
        _selectedCategory = State(initialValue: FlexibleSpendingCategory.map(
            primary: transaction.personal_finance_category,
            detailed: transaction.personal_finance_subcategory
        ))
        self.onTransactionChanged = onTransactionChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetChrome

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero

                    VStack(alignment: .leading, spacing: 20) {
                        merchantSpendCard
                        actionSection
                        detailsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
        .sheet(isPresented: $isCategoryPickerPresented) {
            categoryPicker
                .presentationDetents([.height(500), .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Set repeat", isPresented: $showRepeatFrequencyDialog, titleVisibility: .visible) {
            Button("Weekly") { createRepeat(frequency: "WEEKLY") }
            Button("Monthly") { createRepeat(frequency: "MONTHLY") }
            Button("Annual") { createRepeat(frequency: "ANNUALLY") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark future \(transaction.displayName) transactions as recurring.")
        }
        .alert("Couldn’t update this transaction", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(theme.typography.body(size: 13, weight: .bold))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(Capsule())
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: transaction.id) {
            await loadMerchantHistory()
        }
    }

    private var sheetChrome: some View {
        HStack {
            Spacer()
            closeButton
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(theme.colors.surface.color)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            categoryIcon(size: 50, cornerRadius: 15)
                .padding(.top, 20)

            VStack(spacing: 4) {
                Text(transaction.displayName)
                    .font(theme.typography.title(size: 20, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)

                Text(transactionSubtitle)
                    .font(theme.typography.mono(size: 11, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Text(amountText)
                .font(theme.typography.display(size: 32, weight: .black))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Button {
                selectedCategory = appCategory
                isCategoryPickerPresented = true
            } label: {
                HStack(spacing: 7) {
                    Text(appCategory?.emoji ?? fallbackEmoji)
                        .font(.system(size: 16))
                    categoryLineText(fontSize: 13)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color.white.opacity(0.45))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(categoryTint.opacity(0.55), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                statusPill(
                    title: channelText,
                    systemImage: channelIconName
                )

                statusPill(
                    title: transaction.pending ? "Pending" : "Posted",
                    systemImage: transaction.pending ? "clock" : "checkmark",
                    foreground: transaction.pending ? theme.colors.warning.color : theme.colors.success.color,
                    background: transaction.pending ? theme.colors.warning.color.opacity(0.14) : theme.colors.success.color.opacity(0.15)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(heroBackground)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .frame(width: 38, height: 38)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                }
        }
        .buttonStyle(.plain)
    }

    private var merchantSpendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("YOU & \(merchantShortName.uppercased())")
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                    Text(merchantSummaryText)
                        .font(theme.typography.body(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }

                Spacer()

                Text(merchantThisWeekAmount)
                    .font(theme.typography.body(size: 18, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }

            ZStack {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array(merchantWeeklyBars.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == merchantWeeklyBars.count - 1 ? theme.colors.accent.color : theme.colors.accent.color.opacity(0.35))
                            .opacity(value > 0 ? 1 : 0)
                            .frame(height: value > 0 ? 14 + CGFloat(value) * 58 : 0)
                    }
                }

                if !hasPriorMerchantSpend {
                    Text("First time in 12 weeks")
                        .font(theme.typography.body(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(theme.colors.surfaceMuted.color.opacity(0.7))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 80)

            HStack {
                Text("12 weeks ago")
                Spacer()
                Text("this week")
            }
            .font(theme.typography.body(size: 12, weight: .semibold))
            .foregroundStyle(theme.colors.textSecondary.color)
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("DO SOMETHING")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                actionButton(title: "Split", systemImage: "person.2") {
                    showStatus("Split coming soon")
                }

                actionButton(title: isCreatingRepeat ? "Saving" : "Set repeat", systemImage: "arrow.triangle.2.circlepath") {
                    showRepeatFrequencyDialog = true
                }
                .disabled(isCreatingRepeat)

                actionButton(title: "Add note", systemImage: "doc.text") {
                    showStatus("Notes coming soon")
                }

                actionButton(title: "Hide", systemImage: "eye.slash") {
                    showStatus("Hide coming soon")
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("DETAILS")

            VStack(spacing: 0) {
                ForEach(TransactionDetailDatePresentation(transaction: transaction).rows) { row in
                    detailRow(label: row.label, value: row.value)
                    divider
                }
                detailRow(label: "Account", value: accountText)
                divider
                detailRow(label: "Channel", value: channelText)
                divider
                detailRow(label: "Merchant", value: transaction.displayName)
                if let website = transaction.website, !website.isEmpty {
                    divider
                    detailRow(label: "Website", value: website)
                }
            }
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
        }
    }

    private var categoryPicker: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CATEGORIZE")
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                    Text(transaction.displayName)
                        .font(theme.typography.title(size: 21, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(1)
                }

                Spacer()

                Button { isCategoryPickerPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .frame(width: 38, height: 38)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(availableCategories) { category in
                        categoryPickerCard(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            VStack(spacing: 12) {
                Divider().overlay(theme.colors.line.color)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEW CATEGORY")
                            .font(theme.typography.mono(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(theme.colors.textSecondary.color)
                        Text(newCategoryText)
                            .font(theme.typography.body(size: 14, weight: .black))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    Button {
                        saveSelectedCategory()
                    } label: {
                        HStack(spacing: 8) {
                            if isSavingCategory {
                                ProgressView()
                                    .tint(theme.colors.surface.color)
                            } else {
                                Text("Save")
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(theme.typography.body(size: 16, weight: .black))
                        .foregroundStyle(theme.colors.surface.color)
                        .padding(.horizontal, 22)
                        .frame(height: 50)
                        .background(theme.colors.textPrimary.color)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCategory == nil || isSavingCategory)
                    .opacity(selectedCategory == nil ? 0.45 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(theme.colors.appBackground.color)
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
    }

    private func categoryPickerCard(_ category: FlexibleSpendingCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Text(category.emoji)
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(category.detailTint.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.displayName)
                        .font(theme.typography.body(size: 14, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(category.subtitle)
                        .font(theme.typography.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 2)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(theme.colors.surface.color)
                        .frame(width: 24, height: 24)
                        .background(theme.colors.accent.color)
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .frame(minHeight: 74)
            .background(isSelected ? theme.colors.accent.color.opacity(0.16) : theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? theme.colors.accent.color : theme.colors.line.color, lineWidth: isSelected ? 1.7 : theme.metrics.borderWidth)
            }
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(size: CGFloat, cornerRadius: CGFloat) -> some View {
        Text(appCategory?.emoji ?? fallbackEmoji)
            .font(.system(size: size * 0.42))
            .frame(width: size, height: size)
            .background(categoryTint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.colors.line.color.opacity(0.8), lineWidth: theme.metrics.borderWidth)
            }
    }

    @ViewBuilder
    private func categoryLineText(fontSize: CGFloat) -> some View {
        HStack(spacing: 5) {
            Text(categoryTitle)
                .font(theme.typography.body(size: fontSize, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let subtitle = categoryDetailTitle {
                Text("· \(subtitle)")
                    .font(theme.typography.body(size: fontSize, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private func statusPill(
        title: String,
        systemImage: String,
        foreground: Color? = nil,
        background: Color? = nil
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(theme.typography.body(size: 11, weight: .bold))
            .foregroundStyle(foreground ?? theme.colors.textSecondary.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background ?? theme.colors.surfaceMuted.color)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.colors.line.color.opacity(0.7), lineWidth: theme.metrics.borderWidth)
            }
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .frame(height: 20)
                Text(title)
                    .font(theme.typography.body(size: 11, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.mono(size: 10, weight: .bold))
            .tracking(2)
            .foregroundStyle(theme.colors.textSecondary.color)
            .padding(.leading, 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(theme.typography.body(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            Text(value)
                .font(theme.typography.body(size: 13, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Divider()
            .overlay(theme.colors.line.color.opacity(0.8))
            .padding(.leading, 18)
    }

    private func saveSelectedCategory() {
        guard let selectedCategory else { return }
        guard selectedCategory != appCategory else {
            isCategoryPickerPresented = false
            return
        }

        Task {
            isSavingCategory = true
            defer { isSavingCategory = false }

            do {
                let updated = try await transactionsService.updateTransactionCategory(
                    transactionId: transaction.id,
                    category: selectedCategory
                )
                transaction = updated
                onTransactionChanged(updated)
                isCategoryPickerPresented = false
                showStatus("Category updated")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createRepeat(frequency: String) {
        Task {
            isCreatingRepeat = true
            defer { isCreatingRepeat = false }

            do {
                try await budgetService.createManualStream(transactionId: transaction.id, frequency: frequency)
                showStatus("Repeat saved")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func showStatus(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            statusMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    if statusMessage == message {
                        statusMessage = nil
                    }
                }
            }
        }
    }

    private var availableCategories: [FlexibleSpendingCategory] {
        let tracked = Set((userAccount.profile?.trackedSpendingCategories ?? []).compactMap(FlexibleSpendingCategory.init(rawValue:)))
        guard !tracked.isEmpty else { return FlexibleSpendingCategory.allCases }
        return FlexibleSpendingCategory.allCases.filter { tracked.contains($0) }
    }

    private var appCategory: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(
            primary: transaction.personal_finance_category,
            detailed: transaction.personal_finance_subcategory
        )
    }

    private var categoryTitle: String {
        switch appCategory {
        case .gettingAround:
            return "Transport"
        case .some(let category):
            return category.displayName
        case .none:
            return transaction.isIncome ? "Income" : transaction.isActualTransfer ? "Transfer" : "Other"
        }
    }

    private var categoryDetailTitle: String? {
        if let detailed = transaction.personal_finance_subcategory, !detailed.isEmpty {
            return readableCategoryDetail(detailed)
        }
        return appCategory?.subtitle.capitalized
    }

    private var newCategoryText: String {
        guard let selectedCategory else { return "Choose a category" }
        return "\(selectedCategory.emoji) \(selectedCategory.displayName) · \(selectedCategory.subtitle)"
    }

    private var categoryTint: Color {
        appCategory?.detailTint ?? theme.colors.accent.color
    }

    private var amountColor: Color {
        transaction.isIncome ? theme.colors.success.color : theme.colors.textPrimary.color
    }

    private var heroBackground: Color {
        if transaction.isIncome {
            return theme.colors.success.color.opacity(0.10)
        }
        if transaction.isActualTransfer {
            return theme.colors.surfaceMuted.color
        }
        return categoryTint.opacity(0.18)
    }

    private var amountText: String {
        let value = transaction.absoluteAmount
        let prefix: String
        if transaction.isSpend {
            prefix = "-"
        } else if transaction.isIncome {
            prefix = "+"
        } else {
            prefix = transaction.amount > 0 ? "-" : "+"
        }
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "$\(Int(value.rounded()))"
        return "\(prefix)\(formatted)"
    }

    private var formattedDate: String {
        formatTransactionDate(transaction.spend_date ?? transaction.authorized_date ?? transaction.date, style: .long)
    }

    private var authorizedDateTime: String? {
        guard let raw = transaction.authorized_date, !raw.isEmpty else { return nil }
        if raw.contains("T"), let date = parsedDateTime(raw) {
            return formatDateTime(date, dateFormat: "EEE, MMM d · h:mm a")
        }
        return formatTransactionDate(raw, style: .long)
    }

    private var headerDateTimeText: String {
        if let raw = transaction.created_at, let date = parsedDateTime(raw) {
            return formatDateTime(date, dateFormat: "EEE, MMM d · h:mm a")
        }
        if let raw = transaction.authorized_date, raw.contains("T"), let date = parsedDateTime(raw) {
            return formatDateTime(date, dateFormat: "EEE, MMM d · h:mm a")
        }
        guard let date = parsedDate(transaction.spend_date ?? transaction.authorized_date ?? transaction.date) else {
            return formattedDate
        }
        return formatDateTime(date, dateFormat: "EEE, MMM d")
    }

    private var transactionSubtitle: String {
        headerDateTimeText
    }

    private var channelText: String {
        guard let channel = transaction.payment_channel, !channel.isEmpty else { return "Unknown" }
        return channel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var channelIconName: String {
        let channel = transaction.payment_channel?.lowercased() ?? ""
        if channel.contains("online") {
            return "creditcard"
        }
        if channel.contains("store") || channel.contains("place") {
            return "storefront"
        }
        return "square.grid.2x2"
    }

    private var accountText: String {
        guard let account = lookupAccount(id: transaction.account_id) else {
            return "Account \(transaction.account_id)"
        }

        let type = account.subtype?.replacingOccurrences(of: "_", with: " ").capitalized ?? account.type.capitalized
        let mask = account.mask.map { " · \($0)" } ?? ""
        return "\(account.displayName)\(mask) · \(type)"
    }

    private var merchantShortName: String {
        let name = transaction.merchantName ?? transaction.displayName
        return name.components(separatedBy: " ").first ?? name
    }

    private var merchantSummaryText: String {
        merchantSpendPresentation.summaryText
    }

    private var merchantThisWeekAmount: String {
        merchantSpendPresentation.amountText
    }

    private var merchantSpendPresentation: MerchantSpendPresentation {
        MerchantSpendPresentation(
            transactionCountThisWeek: merchantTransactionsThisWeek.count,
            totalSpentThisWeek: merchantSpendThisWeek
        )
    }

    private var merchantSpendThisWeek: Double {
        merchantTransactionsThisWeek.reduce(0) { $0 + $1.absoluteAmount }
    }

    private var merchantTransactionsThisWeek: [Transaction] {
        let calendar = Calendar.bablo
        return merchantTransactionsForBars.filter { tx in
            guard let date = parsedDate(tx.spend_date ?? tx.authorized_date ?? tx.date) else { return false }
            return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    private var merchantTransactionsForBars: [Transaction] {
        var rows = hasLoadedMerchantHistory ? merchantHistoryTransactions : matchingMerchantTransactions
        if !rows.contains(where: { $0.id == transaction.id }) {
            rows.append(transaction)
        }
        return rows
    }

    private var matchingMerchantTransactions: [Transaction] {
        let merchant = transaction.merchantName ?? transaction.displayName
        return transactionsService.transactions.filter { tx in
            let candidate = tx.merchantName ?? tx.displayName
            return candidate.localizedCaseInsensitiveContains(merchant) ||
                merchant.localizedCaseInsensitiveContains(candidate)
        }
    }

    private var merchantWeeklyBars: [Double] {
        let values = merchantWeeklySpendValues
        let maxValue = max(max(values.max() ?? transaction.absoluteAmount, transaction.absoluteAmount), 1)
        return values.map { $0 > 0 ? $0 / maxValue : 0 }
    }

    private var merchantWeeklySpendValues: [Double] {
        let calendar = Calendar.bablo
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<12).reversed().map { offset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: startOfThisWeek),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                return 0
            }
            return merchantTransactionsForBars.reduce(0) { total, tx in
                guard let date = parsedDate(tx.spend_date ?? tx.authorized_date ?? tx.date),
                      date >= weekStart && date < weekEnd else {
                    return total
                }
                return total + tx.absoluteAmount
            }
        }
    }

    private var hasPriorMerchantSpend: Bool {
        merchantWeeklySpendValues.dropLast().contains { $0 > 0.005 }
    }

    private func loadMerchantHistory() async {
        let startDate = merchantHistoryStartDate
        do {
            merchantHistoryTransactions = try await transactionsService.fetchMerchantTransactions(
                merchantName: transaction.merchantName ?? transaction.displayName,
                startDate: startDate
            )
            hasLoadedMerchantHistory = true
        } catch {
            hasLoadedMerchantHistory = false
        }
    }

    private var merchantHistoryStartDate: String {
        let calendar = Calendar.bablo
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeekStart) ?? thisWeekStart
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: startDate)
    }

    private var fallbackEmoji: String {
        if transaction.isIncome { return "$" }
        if transaction.isActualTransfer { return "<>" }
        return "*"
    }

    private func lookupAccount(id: Int) -> BankAccount? {
        for bank in accountsService.banksWithAccounts {
            if let account = bank.accounts.first(where: { $0.id == id }) {
                return account
            }
        }
        return nil
    }

    private func formatTransactionDate(_ raw: String, style: DateFormatter.Style) -> String {
        guard let date = parsedDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private func readableCategoryDetail(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "TRANSPORTATION_TAXIS_AND_RIDE_SHARES", with: "RIDESHARE")
            .replacingOccurrences(of: "FOOD_AND_DRINK_", with: "")
            .replacingOccurrences(of: "GENERAL_MERCHANDISE_", with: "")
            .replacingOccurrences(of: "TRANSPORTATION_", with: "")
            .replacingOccurrences(of: "ENTERTAINMENT_", with: "")
            .replacingOccurrences(of: "PERSONAL_CARE_", with: "")
            .replacingOccurrences(of: "TRAVEL_", with: "")
            .replacingOccurrences(of: "INCOME_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()

        return normalized
            .split(separator: " ")
            .map { word in
                word.count <= 3 ? word.uppercased() : word.capitalized
            }
            .joined(separator: " ")
    }

    private func parsedDate(_ raw: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = Calendar.bablo.timeZone

        if raw.count >= 10 {
            parser.dateFormat = "yyyy-MM-dd"
            if let date = parser.date(from: String(raw.prefix(10))) {
                return date
            }
        }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private func parsedDateTime(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: raw)
    }
}

private extension FlexibleSpendingCategory {
    var detailTint: Color {
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

// MARK: - Formatter helper

private extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()
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
    .environmentObject(BreakdownTransactionListPreviewFixtures.budgetService)
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
    .environmentObject(BreakdownTransactionListPreviewFixtures.budgetService)
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

    @MainActor static var budgetService: BudgetService {
        BudgetService()
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
