import SwiftUI

struct TransactionDetailHeroView: View {
    @Environment(\.babloTheme) private var theme
    let transaction: Transaction
    let onCategoryTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            categoryIcon(size: 50, cornerRadius: 15)
                .padding(.top, 20)

            VStack(spacing: 4) {
                Text(transaction.displayName)
                    .font(theme.typography.title(size: 20, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

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

            Button(action: onCategoryTap) {
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
                statusPill(title: channelText, systemImage: channelIconName)
                statusPill(
                    title: transaction.pending ? "Pending" : "Posted",
                    systemImage: transaction.pending ? "clock" : "checkmark",
                    foreground: transaction.pending
                        ? theme.colors.warning.color
                        : theme.colors.success.color,
                    background: transaction.pending
                        ? theme.colors.warning.color.opacity(0.14)
                        : theme.colors.success.color.opacity(0.15)
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

    // MARK: - Category

    var appCategory: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(
            primary: transaction.personal_finance_category,
            detailed: transaction.personal_finance_subcategory
        )
    }

    private var categoryTitle: String {
        switch appCategory {
        case .gettingAround: return "Transport"
        case .some(let cat): return cat.displayName
        case .none:
            if transaction.isIncome { return "Income" }
            if transaction.isActualTransfer { return "Transfer" }
            return "Other"
        }
    }

    private var categoryDetailTitle: String? {
        if let detailed = transaction.personal_finance_subcategory, !detailed.isEmpty {
            return readableCategoryDetail(detailed)
        }
        return appCategory?.subtitle.capitalized
    }

    private var categoryTint: Color { appCategory?.detailTint ?? theme.colors.accent.color }

    private var fallbackEmoji: String {
        if transaction.isIncome { return "💰" }
        if transaction.isActualTransfer || transaction.isTransfer { return "↔️" }
        return "💳"
    }

    // MARK: - Amount

    private var amountText: String {
        let value = transaction.absoluteAmount
        let prefix: String
        if transaction.isSpend { prefix = "-" }
        else if transaction.isIncome { prefix = "+" }
        else { prefix = transaction.amount > 0 ? "-" : "+" }
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: value))
            ?? "$\(Int(value.rounded()))"
        return "\(prefix)\(formatted)"
    }

    private var amountColor: Color {
        transaction.isIncome ? theme.colors.success.color : theme.colors.textPrimary.color
    }

    private var heroBackground: Color {
        if transaction.isIncome { return theme.colors.success.color.opacity(0.10) }
        if transaction.isActualTransfer { return theme.colors.surfaceMuted.color }
        return categoryTint.opacity(0.18)
    }

    // MARK: - Channel

    private var channelText: String {
        guard let channel = transaction.payment_channel, !channel.isEmpty else { return "Unknown" }
        return channel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var channelIconName: String {
        let channel = transaction.payment_channel?.lowercased() ?? ""
        if channel.contains("online") { return "creditcard" }
        if channel.contains("store") || channel.contains("place") { return "storefront" }
        return "square.grid.2x2"
    }

    // MARK: - Date

    private var transactionSubtitle: String { headerDateTimeText }

    private var headerDateTimeText: String {
        if let raw = transaction.created_at,
           let date = TransactionDateParser.parsedDateTime(raw) {
            return TransactionDateParser.formatDateTime(date, format: "EEE, MMM d · h:mm a")
        }
        if let raw = transaction.authorized_date,
           raw.contains("T"),
           let date = TransactionDateParser.parsedDateTime(raw) {
            return TransactionDateParser.formatDateTime(date, format: "EEE, MMM d · h:mm a")
        }
        let rawDate = transaction.spend_date ?? transaction.authorized_date ?? transaction.date
        guard let date = TransactionDateParser.parsedDate(rawDate) else {
            return TransactionDateParser.formatDate(rawDate, style: .long)
        }
        return TransactionDateParser.formatDateTime(date, format: "EEE, MMM d")
    }

    // MARK: - Sub-views

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

    // MARK: - Formatting

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
            .map { word in word.count <= 3 ? word.uppercased() : word.capitalized }
            .joined(separator: " ")
    }
}
