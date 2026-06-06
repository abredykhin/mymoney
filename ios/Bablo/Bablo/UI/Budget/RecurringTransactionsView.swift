import SwiftUI

struct RecurringTransactionsView: View {
    @StateObject private var subService = SubscriptionsService()
    @State private var showingIncomeOnly = false
    @State private var showingExpensesOnly = false
    @State private var isRefreshing = false

    var filteredStreams: [RecurringStream] {
        subService.allRecurringStreams.filter { stream in
            if showingIncomeOnly && stream.type != "income" { return false }
            if showingExpensesOnly && stream.type != "expense" { return false }
            return true
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            isRefreshing = true
                            try? await subService.syncRecurringTransactions()
                            isRefreshing = false
                        }
                    }) {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Sync from Plaid")
                        }
                    }
                    .disabled(isRefreshing)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section("Filters") {
                Toggle("Income Only", isOn: $showingIncomeOnly)
                Toggle("Expenses Only", isOn: $showingExpensesOnly)
            }

            Section {
                if filteredStreams.isEmpty {
                    Text("No recurring transactions found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(filteredStreams) { stream in
                        RecurringStreamRow(stream: stream)
                    }
                }
            } header: {
                Text("Recurring Transactions")
            } footer: {
                Text("Plaid automatically detects recurring income and expenses. You can override these classifications below.")
                    .font(.caption)
            }
        }
        .navigationTitle("Recurring Transactions")
        .task {
            try? await subService.fetchSubscriptions()
        }
    }
}

struct RecurringStreamRow: View {
    let stream: RecurringStream
    @State private var isExpanded = false
    @State private var isMarkedRecurring: Bool
    @State private var isExcluded: Bool
    @StateObject private var subService = SubscriptionsService()

    init(stream: RecurringStream) {
        self.stream = stream
        self._isMarkedRecurring = State(initialValue: stream.userMarkedRecurring ?? true)
        self._isExcluded = State(initialValue: stream.isExcluded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(stream.description)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(stream.frequencyDisplay)
                        Text("•")
                        Text("$\(stream.averageAmount, specifier: "%.2f")")
                        if stream.status == "EARLY_DETECTION" {
                            Text("•")
                            Text("Early")
                                .foregroundColor(.orange)
                        }
                        if let nextDate = stream.predictedNextDate {
                            Text("•")
                            Text("Next: \(formatDate(nextDate))")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("$\(stream.monthlyAmount, specifier: "%.2f")/mo")
                        .font(.callout)
                        .fontWeight(.semibold)

                    Text(stream.type == "income" ? "Income" : "Expense")
                        .font(.caption2)
                        .foregroundColor(stream.type == "income" ? .green : .red)
                }
            }

            if isExpanded {
                Divider()

                VStack(spacing: 12) {
                    Toggle("Mark as Recurring", isOn: $isMarkedRecurring)
                        .onChange(of: isMarkedRecurring) { _, newValue in
                            Task { await updateStreamOverride(recurring: newValue) }
                        }

                    Toggle("Exclude from Budget", isOn: $isExcluded)
                        .onChange(of: isExcluded) { _, newValue in
                            Task { await updateStreamExclusion(excluded: newValue) }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        if let firstDate = stream.firstDate {
                            Text("First seen: \(firstDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let lastDate = stream.lastDate {
                            Text("Last seen: \(lastDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let merchantName = stream.merchantName {
                            Text("Merchant: \(merchantName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isExpanded.toggle() }
        }
    }

    func updateStreamOverride(recurring: Bool) async {
        do {
            try await SupabaseManager.shared.client
                .from("recurring_streams_table")
                .update(["user_marked_recurring": recurring])
                .eq("id", value: stream.id)
                .execute()

            Logger.i("Updated stream \(stream.id) recurring status to \(recurring)")
            try? await subService.fetchSubscriptions()
        } catch {
            Logger.e("Failed to update stream override: \(error)")
        }
    }

    func updateStreamExclusion(excluded: Bool) async {
        do {
            try await SupabaseManager.shared.client
                .from("recurring_streams_table")
                .update(["is_excluded": excluded])
                .eq("id", value: stream.id)
                .execute()

            Logger.i("Updated stream \(stream.id) exclusion status to \(excluded)")
            try? await subService.fetchSubscriptions()
        } catch {
            Logger.e("Failed to update stream exclusion: \(error)")
        }
    }

    func formatDate(_ dateString: String) -> String {
        let parts = dateString.split(separator: "-")
        if parts.count == 3 { return "\(parts[1])/\(parts[2])" }
        return dateString
    }
}
