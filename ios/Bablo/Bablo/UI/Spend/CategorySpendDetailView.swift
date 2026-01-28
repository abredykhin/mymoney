import SwiftUI

struct CategorySpendDetailView: View {
    let category: String
    let range: SpendDateRange
    @StateObject private var transactionsService = TransactionsService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {

        VStack(spacing: 0) {
            // Header
            HStack {
                Text(getTransactionCategoryDescription(transactionCategory: category))
                    .font(Typography.h2)
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .padding()

            if transactionsService.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if transactionsService.transactions.isEmpty {
                Spacer()
                Text("No transactions for this category in the selected period.")
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("\(range.displayName) Transactions")
                            .font(Typography.footnote)
                            .foregroundColor(ColorPalette.textSecondary)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(transactionsService.transactions, id: \.id) { transaction in
                                TransactionView(transaction: transaction)
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(ColorPalette.backgroundPrimary.ignoresSafeArea())
        .task {
            // Slight delay to ensure view is ready
            try? await Task.sleep(nanoseconds: 100_000_000)
            await fetchTransactions()
        }
    }

    private func fetchTransactions() async {
        let filter = TransactionFilter(
            personalFinanceCategory: category,
            startDate: range.startDate(),
            endDate: range.endDate()
        )
        let options = FetchOptions(limit: 100, filter: filter)
        try? await transactionsService.fetchTransactions(options: options)
    }
}
