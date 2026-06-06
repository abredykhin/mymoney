import SwiftUI

struct RecentWidgetView: View {
    @EnvironmentObject private var transactionsService: TransactionsService
    @EnvironmentObject private var navigationState: NavigationState
    @Environment(\.babloTheme) private var theme
    @State private var selectedTransaction: Transaction?

    private var recentTransactions: [Transaction] {
        // Hide internal transfers (account-to-account moves, brokerage credits, card
        // payments) — anything that is neither spend nor income. They aren't real
        // "moves" the user makes and clutter the feed.
        Array(transactionsService.transactions.filter { !$0.isActualTransfer }.prefix(8))
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent")
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    Text(recentTransactions.isEmpty ? "No activity yet" : "\(recentTransactions.count) latest moves")
                        .font(theme.typography.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }

                Spacer()

                Button {
                    navigationState.homeNavPath.append(HomeDestination.allTransactions)
                } label: {
                    HStack(spacing: 4) {
                        Text("All")
                            .font(theme.typography.body(size: 13, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.top, 3)
                }
                .buttonStyle(.plain)
            }

            if recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "receipt")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                        Text("Recent transactions will land here")
                            .font(theme.typography.body(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            RecentTransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)

                        if transaction.id != recentTransactions.last?.id {
                            Divider()
                                .overlay(theme.colors.line.color.opacity(0.6))
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .padding(16)
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
            color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04),
            radius: isPopArt ? 0 : 16,
            x: isPopArt ? 3 : 0,
            y: isPopArt ? 3 : 6
        )
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailSheet(transaction: txn) { updated in
                selectedTransaction = updated
                transactionsService.replaceTransaction(updated)
            }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct RecentTransactionRow: View {
    let transaction: Transaction

    @Environment(\.babloTheme) private var theme

    private var amountColor: Color {
        if transaction.isSpend {
            return theme.colors.textPrimary.color
        } else if transaction.isIncome {
            return theme.colors.accent.color
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
                    .frame(width: 32, height: 32)

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
                Text(transaction.truncatedDisplayName)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                Text(presentation.categoryText)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(presentation.amountText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
    }
}

struct RecentTransactionPresentation {
    let amountText: String
    let categoryText: String
    let iconName: String
    let usesSystemIcon: Bool

    init(transaction: Transaction) {
        amountText = Self.amountText(for: transaction)
        categoryText = Self.categoryText(for: transaction)
        iconName = Self.iconName(for: transaction)
        usesSystemIcon = Self.usesSystemIcon(for: transaction)
    }

    private static func amountText(for transaction: Transaction) -> String {
        let value = transaction.absoluteAmount
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.isoCurrencyCode ?? "USD"
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2

        let formatted = formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value.rounded()))"
        
        if transaction.isSpend {
            return "-\(formatted)"
        } else if transaction.isIncome {
            return "+\(formatted)"
        } else {
            return transaction.amount > 0 ? "-\(formatted)" : "+\(formatted)"
        }
    }

    private static func categoryText(for transaction: Transaction) -> String {
        if transaction.isActualTransfer {
            return "Transfer"
        }
        if let category = FlexibleSpendingCategory.map(
            primary: transaction.personalFinanceCategory,
            detailed: transaction.personalFinanceSubcategory
        ) {
            return category.displayName
        }
        let category = transaction.personalFinanceCategory ?? transaction.primaryCategory ?? "Transaction"
        return category
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }

    private static func iconName(for transaction: Transaction) -> String {
        if transaction.isActualTransfer {
            return "arrow.left.arrow.right"
        }
        if let category = FlexibleSpendingCategory.map(
            primary: transaction.personalFinanceCategory,
            detailed: transaction.personalFinanceSubcategory
        ) {
            return category.emoji
        }
        let category = (transaction.personalFinanceCategory ?? transaction.primaryCategory ?? "").lowercased()
        if category.contains("food") || category.contains("restaurant") {
            return "fork.knife"
        } else if category.contains("transport") || category.contains("travel") {
            return "car.fill"
        } else if category.contains("shops") || category.contains("merchandise") {
            return "bag.fill"
        } else if category.contains("income") {
            return "arrow.down.circle.fill"
        } else if category.contains("transfer") {
            return "arrow.left.arrow.right"
        }

        return "creditcard.fill"
    }

    private static func usesSystemIcon(for transaction: Transaction) -> Bool {
        if transaction.isActualTransfer {
            return true
        }
        return FlexibleSpendingCategory.map(
            primary: transaction.personalFinanceCategory,
            detailed: transaction.personalFinanceSubcategory
        ) == nil
    }
}

#if DEBUG

#Preview("Recent Widget · Populated") {
    RecentWidgetView()
        .environmentObject(RecentWidgetPreviewFixtures.transactionsService())
        .environmentObject(NavigationState())
        .babloTheme(.normal)
        .padding()
        .babloScreenBackground()
}

#Preview("Recent Widget · Empty") {
    RecentWidgetView()
        .environmentObject(RecentWidgetPreviewFixtures.emptyTransactionsService())
        .environmentObject(NavigationState())
        .babloTheme(.pop)
        .padding()
        .babloScreenBackground()
}

@MainActor
private enum RecentWidgetPreviewFixtures {
    static func transactionsService() -> TransactionsService {
        let service = TransactionsService()
        service.transactions = [
            transaction(
                id: 1,
                amount: 18.42,
                date: "2026-06-05",
                name: "Blue Bottle Coffee",
                merchant: "Blue Bottle",
                primary: "FOOD_AND_DRINK",
                detailed: "FOOD_AND_DRINK_COFFEE",
                isSpend: true,
                isIncome: false
            ),
            transaction(
                id: 2,
                amount: 64.18,
                date: "2026-06-05",
                name: "Trader Joe's",
                merchant: "Trader Joe's",
                primary: "GENERAL_MERCHANDISE",
                detailed: "GENERAL_MERCHANDISE_SUPERSTORES",
                isSpend: true,
                isIncome: false
            ),
            transaction(
                id: 3,
                amount: -2_850,
                date: "2026-06-04",
                name: "Payroll Deposit",
                merchant: nil,
                primary: "INCOME",
                detailed: "INCOME_WAGES",
                isSpend: false,
                isIncome: true
            ),
            transaction(
                id: 4,
                amount: 32.70,
                date: "2026-06-04",
                name: "Lyft",
                merchant: "Lyft",
                primary: "TRANSPORTATION",
                detailed: "TRANSPORTATION_TAXIS_AND_RIDE_SHARES",
                isSpend: true,
                isIncome: false
            ),
            transaction(
                id: 5,
                amount: 84.12,
                date: "2026-06-03",
                name: "Amazon Marketplace",
                merchant: "Amazon",
                primary: "GENERAL_MERCHANDISE",
                detailed: "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES",
                isSpend: true,
                isIncome: false
            )
        ]
        return service
    }

    static func emptyTransactionsService() -> TransactionsService {
        TransactionsService()
    }

    private static func transaction(
        id: Int,
        amount: Double,
        date: String,
        name: String,
        merchant: String?,
        primary: String,
        detailed: String,
        isSpend: Bool,
        isIncome: Bool
    ) -> Transaction {
        Transaction(
            id: id,
            account_id: 10,
            amount: amount,
            date: date,
            authorized_date: date,
            name: name,
            merchant_name: merchant,
            pending: false,
            category: nil,
            transaction_id: "preview_tx_\(id)",
            pending_transaction_transaction_id: nil,
            iso_currency_code: "USD",
            payment_channel: "in store",
            user_id: nil,
            logo_url: nil,
            website: nil,
            personal_finance_category: primary,
            personal_finance_subcategory: detailed,
            created_at: nil,
            updated_at: nil,
            is_spend: isSpend,
            is_income: isIncome
        )
    }
}

#endif
