import SwiftUI

// MARK: - Supporting types

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
            TransactionDateParser.formatDate(
                transaction.spend_date ?? transaction.authorized_date ?? transaction.date,
                style: .long
            )
        rows = [Row(label: "Authorized", value: value)]
    }

    private static func authorizedDateTime(for transaction: Transaction) -> String? {
        if let raw = transaction.authorized_datetime,
           let date = TransactionDateParser.parsedDateTime(raw) {
            return TransactionDateParser.formatDateTime(date, format: "EEE, MMM d · h:mm a")
        }
        guard let raw = transaction.authorized_date, !raw.isEmpty else { return nil }
        return TransactionDateParser.formatDate(raw, style: .long)
    }
}

// MARK: - Sheet

struct TransactionDetailSheet: View {
    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountsService: AccountsService
    @EnvironmentObject private var subService: SubscriptionsService
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
                    TransactionDetailHeroView(transaction: transaction) {
                        selectedCategory = appCategory
                        isCategoryPickerPresented = true
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        MerchantSpendCardView(
                            provider: merchantDataProvider,
                            merchantShortName: merchantShortName
                        )
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
            TransactionCategoryPickerView(
                transactionName: transaction.displayName,
                selectedCategory: $selectedCategory,
                availableCategories: availableCategories,
                isSavingCategory: isSavingCategory,
                onDismiss: { isCategoryPickerPresented = false },
                onSave: saveSelectedCategory
            )
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
        .alert("Couldn't update this transaction", isPresented: Binding(
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

    // MARK: - Sub-views

    private var sheetChrome: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .frame(width: 38, height: 38)
                    .background(theme.colors.surfaceMuted.color)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(theme.colors.surface.color)
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
                    rowDivider
                }
                detailRow(label: "Account", value: accountText)
                rowDivider
                detailRow(label: "Channel", value: channelText)
                rowDivider
                detailRow(label: "Merchant", value: transaction.displayName)
                if let website = transaction.website, !website.isEmpty {
                    rowDivider
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

    // MARK: - Shared UI helpers

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
                .lineLimit(nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(theme.colors.line.color.opacity(0.8))
            .padding(.leading, 18)
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

    // MARK: - Merchant data

    private var merchantDataProvider: MerchantWeeklyDataProvider {
        var rows = hasLoadedMerchantHistory ? merchantHistoryTransactions : matchingMerchantTransactions
        if !rows.contains(where: { $0.id == transaction.id }) {
            rows.append(transaction)
        }
        return MerchantWeeklyDataProvider(transactions: rows, currentTransaction: transaction)
    }

    private var matchingMerchantTransactions: [Transaction] {
        let merchant = transaction.merchantName ?? transaction.displayName
        return transactionsService.transactions.filter { tx in
            let candidate = tx.merchantName ?? tx.displayName
            return candidate.localizedCaseInsensitiveContains(merchant) ||
                merchant.localizedCaseInsensitiveContains(candidate)
        }
    }

    private var merchantShortName: String {
        let name = transaction.merchantName ?? transaction.displayName
        return name.components(separatedBy: " ").first ?? name
    }

    // MARK: - Computed helpers

    private var appCategory: FlexibleSpendingCategory? {
        FlexibleSpendingCategory.map(
            primary: transaction.personal_finance_category,
            detailed: transaction.personal_finance_subcategory
        )
    }

    private var channelText: String {
        guard let channel = transaction.payment_channel, !channel.isEmpty else { return "Unknown" }
        return channel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var accountText: String {
        guard let account = lookupAccount(id: transaction.account_id) else {
            return "Account \(transaction.account_id)"
        }
        let type = account.subtype?.replacingOccurrences(of: "_", with: " ").capitalized ?? account.type.capitalized
        let mask = account.mask.map { " · \($0)" } ?? ""
        return "\(account.displayName)\(mask) · \(type)"
    }

    private var availableCategories: [FlexibleSpendingCategory] {
        let tracked = Set(
            (userAccount.profile?.trackedSpendingCategories ?? [])
                .compactMap(FlexibleSpendingCategory.init(rawValue:))
        )
        guard !tracked.isEmpty else { return FlexibleSpendingCategory.allCases }
        return FlexibleSpendingCategory.allCases.filter { tracked.contains($0) }
    }

    private func lookupAccount(id: Int) -> BankAccount? {
        for bank in accountsService.banksWithAccounts {
            if let account = bank.accounts.first(where: { $0.id == id }) { return account }
        }
        return nil
    }

    // MARK: - Actions

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
                try await subService.createManualStream(transactionId: transaction.id, frequency: frequency)
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
                    if statusMessage == message { statusMessage = nil }
                }
            }
        }
    }

    private func loadMerchantHistory() async {
        let calendar = Calendar.bablo
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeekStart) ?? thisWeekStart
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        do {
            merchantHistoryTransactions = try await transactionsService.fetchMerchantTransactions(
                merchantName: transaction.merchantName ?? transaction.displayName,
                startDate: formatter.string(from: startDate)
            )
            hasLoadedMerchantHistory = true
        } catch {
            hasLoadedMerchantHistory = false
        }
    }
}

// MARK: - Extensions

extension FlexibleSpendingCategory {
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

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()
}

#Preview {
    let mockTx = Transaction(
        id: 1,
        account_id: 10,
        amount: 25.50,
        date: "2026-06-05",
        authorized_date: "2026-06-05",
        name: "Blue Bottle Coffee",
        merchant_name: "Blue Bottle",
        pending: false,
        category: nil,
        transaction_id: "preview_tx_1",
        pending_transaction_transaction_id: nil,
        iso_currency_code: "USD",
        payment_channel: "in store",
        user_id: nil,
        logo_url: nil,
        website: nil,
        personal_finance_category: "FOOD_AND_DRINK",
        personal_finance_subcategory: "FOOD_AND_DRINK_COFFEE",
        created_at: nil,
        updated_at: nil,
        is_spend: true,
        is_income: false
    )
    return TransactionDetailSheet(transaction: mockTx)
        .environmentObject(AccountsService())
        .environmentObject(SubscriptionsService())
        .environmentObject(TransactionsService())
        .environmentObject(UserAccount())
}

