import SwiftUI

struct RecentWidgetView: View {
    @EnvironmentObject private var transactionsService: TransactionsService
    @EnvironmentObject private var navigationState: NavigationState
    @Environment(\.babloTheme) private var theme
    @State private var selectedTransaction: Transaction?

    private var recentTransactions: [Transaction] {
        Array(transactionsService.transactions.prefix(8))
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
                    Text("All >")
                        .font(theme.typography.body(size: 13, weight: .bold))
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

                Image(systemName: presentation.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
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

    init(transaction: Transaction) {
        amountText = Self.amountText(for: transaction)
        categoryText = Self.categoryText(for: transaction)
        iconName = Self.iconName(for: transaction)
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
}
