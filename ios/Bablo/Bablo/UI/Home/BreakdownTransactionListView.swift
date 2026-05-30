import SwiftUI

// MARK: - Main View

/// Pushed from a tappable step card in MoneyLeftBreakdownView.
/// Shows the pool of transactions that make up that step, and lets the user
/// tap any row to see a detail sheet.
struct BreakdownTransactionListView: View {
    let source: BreakdownTransactionSource
    let period: HeroPeriod

    @EnvironmentObject private var budgetService: BudgetService
    @Environment(\.babloTheme) private var theme

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var selectedTransaction: Transaction?

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
            TransactionDetailSheet(transaction: txn)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            guard source != .obligations else { return }
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
                    .foregroundStyle(transaction.isExpense ? theme.colors.textPrimary.color : theme.colors.success.color)
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
        let prefix = transaction.isExpense ? "-" : "+"
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

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(theme.colors.line.color)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Amount hero
                    VStack(alignment: .center, spacing: 6) {
                        Text(amountText)
                            .font(theme.typography.display(size: 44, weight: .black))
                            .foregroundStyle(transaction.isExpense ? theme.colors.textPrimary.color : theme.colors.success.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)

                        if transaction.pending {
                            Label("Pending", systemImage: "clock")
                                .font(theme.typography.body(size: 13, weight: .semibold))
                                .foregroundStyle(theme.colors.warning.color)
                        }
                    }
                    .padding(.bottom, 28)

                    // Detail rows
                    VStack(spacing: 0) {
                        detailRow(label: "Merchant", value: transaction.displayName)
                        Divider().overlay(theme.colors.line.color)
                        detailRow(label: "Date", value: formattedDate)
                        Divider().overlay(theme.colors.line.color)
                        if let cat = friendlyCategory {
                            detailRow(label: "Category", value: cat)
                            Divider().overlay(theme.colors.line.color)
                        }
                        if let channel = transaction.payment_channel?.replacingOccurrences(of: "_", with: " ").capitalized {
                            detailRow(label: "Channel", value: channel)
                        }
                    }
                    .background(theme.colors.surface.color)
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                            .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(theme.typography.body(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            Text(value)
                .font(theme.typography.body(size: 14, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var amountText: String {
        let value = transaction.absoluteAmount
        let prefix = transaction.isExpense ? "-" : "+"
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
        display.dateStyle = .long
        display.timeStyle = .none
        return display.string(from: date)
    }

    private var friendlyCategory: String? {
        (transaction.personal_finance_category ?? transaction.primaryCategory)
            .map {
                $0.replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                    .capitalized
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
