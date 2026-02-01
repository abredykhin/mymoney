## 10. iOS Changes

### 10.1 Update `BudgetService.swift`

**Add new data models:**

```swift
/// A recurring transaction stream from Plaid or user-created
struct RecurringStream: Codable, Identifiable, Equatable {
    let id: Int
    let plaidStreamId: String?
    let description: String
    let merchantName: String?
    let personalFinanceCategory: String?  // Matches DB: stores PRIMARY value
    let personalFinanceSubcategory: String?  // Matches DB: stores DETAILED value
    let frequency: String // WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY
    let averageAmount: Double
    let monthlyAmount: Double
    let isoCurrencyCode: String?
    let type: String // income or expense
    let status: String // MATURE, EARLY_DETECTION, TOMBSTONED, MANUAL
    let isActive: Bool
    let firstDate: String?
    let lastDate: String?
    let predictedNextDate: String?
    let isUserModified: Bool
    let userMarkedRecurring: Bool?
    let isExcluded: Bool
    let isManual: Bool
    let matchPattern: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plaidStreamId = "plaid_stream_id"
        case description
        case merchantName = "merchant_name"
        case personalFinanceCategory = "personal_finance_category"
        case personalFinanceSubcategory = "personal_finance_subcategory"
        case frequency
        case averageAmount = "average_amount"
        case monthlyAmount = "monthly_amount"
        case isoCurrencyCode = "iso_currency_code"
        case type
        case status
        case isActive = "is_active"
        case firstDate = "first_date"
        case lastDate = "last_date"
        case predictedNextDate = "predicted_next_date"
        case isUserModified = "is_user_modified"
        case userMarkedRecurring = "user_marked_recurring"
        case isExcluded = "is_excluded"
        case isManual = "is_manual"
        case matchPattern = "match_pattern"
    }

    /// Human-readable frequency label
    var frequencyDisplay: String {
        switch frequency {
        case "WEEKLY": return "Weekly"
        case "SEMI_MONTHLY": return "Twice Monthly"
        case "MONTHLY": return "Monthly"
        case "ANNUALLY": return "Yearly"
        default: return frequency.capitalized
        }
    }
}

/// Request model for creating manual recurring stream
struct CreateManualStreamRequest: Codable {
    let transaction_id: Int
    let frequency: String
    let user_id: String
}
```

**Add to BudgetService class:**

```swift
// Add to published properties
@Published var allRecurringStreams: [RecurringStream] = []
```

**Replace `fetchBudgetItems()` method:**

```swift
/// Fetch all recurring streams (income and expenses) from Plaid
func fetchRecurringStreams() async {
    guard let userId = UserAccount.shared.currentUser?.id else { return }

    do {
        let streams: [RecurringStream] = try await supabase
            .from("recurring_streams_table")
            .select("*")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .eq("is_excluded", value: false)
            .execute()
            .value

        self.allRecurringStreams = streams
        Logger.i("BudgetService: Loaded \(streams.count) recurring streams from Plaid")
    } catch {
        Logger.e("BudgetService: Failed to fetch recurring streams: \(error)")
    }
}
```

**Update `fetchActualIncome()` method:**

```swift
/// Fetch actual income transactions for the current month and categorize them
func fetchActualIncome() async {
    guard let userId = UserAccount.shared.currentUser?.id else { return }

    let range = SpendDateRange.month
    let startDate = range.startDate()
    let endDate = range.endDate()

    do {
        // Fetch income transactions that are NOT already marked as recurring
        let transactions: [TransactionForBreakdown] = try await supabase
            .from("transactions")
            .select("amount, name, type, is_recurring")
            .gte("date", value: startDate)
            .lte("date", value: endDate)
            .lt("amount", value: 0) // Negative = Money In
            .execute()
            .value

        let incomeStreams = allRecurringStreams
            .filter { $0.type == "income" }

        var knownTotal: Double = 0
        var extraTotal: Double = 0

        for tx in transactions {
            // Skip credit/loan account inflows
            if tx.type == "credit" || tx.type == "loan" {
                Logger.d("BudgetService: Ignoring income-like transaction on \(tx.type ?? "unknown") account")
                continue
            }

            let amount = abs(tx.amount)

            // If already marked as recurring by backend, count as known
            if tx.isRecurring == true {
                knownTotal += amount
            } else {
                // This is a one-off income transaction
                extraTotal += amount
            }
        }

        self.knownIncomeThisMonth = knownTotal
        self.extraIncomeThisMonth = extraTotal

        Logger.i("BudgetService: Income Analysis - Known: $\(knownTotal), Extra: $\(extraTotal)")

    } catch {
        Logger.e("BudgetService: Failed to fetch actual income: \(error)")
    }
}
```

**Update `fetchBudgetSummary()` method:**

Replace the call to `fetchBudgetItems()` with `fetchRecurringStreams()`:

```swift
func fetchBudgetSummary() async {
    guard let userId = UserAccount.shared.currentUser?.id else {
        Logger.e("BudgetService: Cannot fetch budget summary - no user ID")
        return
    }

    Logger.d("BudgetService: Fetching budget summary for \(userId)")

    do {
        let profile: Profile = try await supabase
            .from("profiles")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        self.monthlyIncome = profile.monthlyIncome
        self.monthlyMandatoryExpenses = profile.monthlyMandatoryExpenses
        Logger.i("BudgetService: Loaded profile successfully for \(userId)")
        Logger.d("BudgetService: -> monthly_income (expected): \(monthlyIncome)")
        Logger.d("BudgetService: -> monthly_mandatory_expenses: \(monthlyMandatoryExpenses)")

        await fetchRecurringStreams() // CHANGED: was fetchBudgetItems()
        await fetchActualIncome()
        try? await fetchVariableSpend()
    } catch {
        Logger.e("BudgetService: Failed to fetch budget summary: \(error)")
    }
}
```

**Add new method to trigger recurring sync:**

```swift
/// Manually trigger a recurring transaction sync from Plaid
func syncRecurringTransactions() async throws {
    Logger.d("BudgetService: Triggering recurring transaction sync")

    // Get user's first item (or iterate through all items)
    guard let userId = UserAccount.shared.currentUser?.id else {
        throw BudgetError.noUser
    }

    struct ItemID: Codable { let plaid_item_id: String }
    let items: [ItemID] = try await supabase
        .from("items_table")
        .select("plaid_item_id")
        .eq("user_id", value: userId)
        .eq("is_active", value: true)
        .execute()
        .value

    guard let firstItem = items.first else {
        Logger.w("BudgetService: No active items found for recurring sync")
        return
    }

    let body = [
        "plaid_item_id": firstItem.plaid_item_id,
        "user_id": userId
    ]
    let bodyData = try JSONSerialization.data(withJSONObject: body)

    try await supabase.functions.invoke(
        "sync-recurring-transactions",
        options: FunctionInvokeOptions(body: bodyData)
    )

    Logger.i("BudgetService: Recurring transaction sync triggered")

    // Refresh data after sync
    await fetchBudgetSummary()
}

/// Create a manual recurring stream from a transaction
func createManualStream(transactionId: Int, frequency: String) async throws {
    Logger.d("BudgetService: Creating manual stream for transaction \(transactionId)")

    guard let userId = UserAccount.shared.currentUser?.id else {
        throw BudgetError.noUser
    }

    let body: [String: Any] = [
        "transaction_id": transactionId,
        "frequency": frequency,
        "user_id": userId
    ]
    let bodyData = try JSONSerialization.data(withJSONObject: body)

    let response = try await supabase.functions.invoke(
        "create-manual-stream",
        options: FunctionInvokeOptions(body: bodyData)
    )

    Logger.i("BudgetService: Manual stream created successfully")

    // Refresh data after creating stream
    await fetchBudgetSummary()
}

/// Delete a manual recurring stream
func deleteManualStream(streamId: Int) async throws {
    Logger.d("BudgetService: Deleting manual stream \(streamId)")

    try await supabase
        .from("recurring_streams_table")
        .delete()
        .eq("id", value: streamId)
        .eq("is_manual", value: true) // Safety: only allow deleting manual streams
        .execute()

    Logger.i("BudgetService: Manual stream deleted")

    // Refresh data after deletion
    await fetchBudgetSummary()
}

enum BudgetError: Error {
    case noUser
}
```

**Update transaction model:**

```swift
private struct TransactionForBreakdown: Codable {
    let id: Int?
    let amount: Double
    let name: String
    let personalFinanceCategory: String?
    let type: String?
    let isRecurring: Bool? // NEW

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case name
        case personalFinanceCategory = "personal_finance_category"
        case type
        case isRecurring = "is_recurring"
    }
}
```

**Remove reference to `checkAndTriggerBudgetAnalysis()`:**

Delete the entire `checkAndTriggerBudgetAnalysis()` method as it's no longer needed.

### 10.2 Create New UI: `RecurringTransactionsView.swift`

Location: `/ios/Bablo/Bablo/UI/Budget/RecurringTransactionsView.swift`

This view allows users to:
- See all their recurring income and expenses
- Toggle streams as recurring/non-recurring
- Exclude streams from budget calculations
- See which transactions belong to each stream

```swift
import SwiftUI

struct RecurringTransactionsView: View {
    @StateObject private var budgetService = BudgetService()
    @State private var showingIncomeOnly = false
    @State private var showingExpensesOnly = false
    @State private var isRefreshing = false

    var filteredStreams: [RecurringStream] {
        budgetService.allRecurringStreams.filter { stream in
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
                            try? await budgetService.syncRecurringTransactions()
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
            await budgetService.fetchRecurringStreams()
        }
    }
}

struct RecurringStreamRow: View {
    let stream: RecurringStream
    @State private var isExpanded = false
    @State private var isMarkedRecurring: Bool
    @State private var isExcluded: Bool
    @StateObject private var budgetService = BudgetService()

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
                        .onChange(of: isMarkedRecurring) { newValue in
                            Task {
                                await updateStreamOverride(recurring: newValue)
                            }
                        }

                    Toggle("Exclude from Budget", isOn: $isExcluded)
                        .onChange(of: isExcluded) { newValue in
                            Task {
                                await updateStreamExclusion(excluded: newValue)
                            }
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
            withAnimation {
                isExpanded.toggle()
            }
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

            // Refresh budget after update
            await budgetService.fetchBudgetSummary()
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

            // Refresh budget after update
            await budgetService.fetchBudgetSummary()
        } catch {
            Logger.e("Failed to update stream exclusion: \(error)")
        }
    }

    func formatDate(_ dateString: String) -> String {
        // Simple MM/DD format
        let parts = dateString.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[1])/\(parts[2])"
        }
        return dateString
    }
}
```

### 10.3 Add "Mark as Recurring" to Transaction Detail View

Update your transaction detail view to allow marking individual transactions as recurring:

```swift
// In TransactionDetailView or similar
struct TransactionDetailView: View {
    let transaction: Transaction
    @StateObject private var budgetService = BudgetService()
    @State private var showingFrequencyPicker = false
    @State private var selectedFrequency = "monthly"

    let frequencies = ["weekly", "semi_monthly", "monthly", "quarterly", "annually"]

    var body: some View {
        List {
            // ... existing transaction details ...

            Section("Recurring Status") {
                if transaction.isRecurring {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Marked as Recurring")
                        Spacer()
                        Button("Manage") {
                            // Navigate to RecurringTransactionsView
                        }
                    }
                } else {
                    Button(action: {
                        showingFrequencyPicker = true
                    }) {
                        HStack {
                            Image(systemName: "repeat")
                            Text("Mark as Recurring")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFrequencyPicker) {
            FrequencyPickerSheet(
                selectedFrequency: $selectedFrequency,
                onConfirm: {
                    Task {
                        try? await budgetService.createManualStream(
                            transactionId: transaction.id,
                            frequency: selectedFrequency
                        )
                        showingFrequencyPicker = false
                    }
                }
            )
        }
    }
}

struct FrequencyPickerSheet: View {
    @Binding var selectedFrequency: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    let frequencies = [
        ("weekly", "Weekly"),
        ("semi_monthly", "Twice Monthly"),
        ("monthly", "Monthly"),
        ("quarterly", "Quarterly"),
        ("annually", "Yearly")
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(frequencies, id: \.0) { frequency in
                        Button(action: {
                            selectedFrequency = frequency.0
                        }) {
                            HStack {
                                Text(frequency.1)
                                Spacer()
                                if selectedFrequency == frequency.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("How often does this charge occur?")
                } footer: {
                    Text("This will create a recurring stream and mark all matching transactions as recurring.")
                        .font(.caption)
                }
            }
            .navigationTitle("Mark as Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### 10.4 Update RecurringTransactionsView to Support Manual Streams

Add UI to distinguish between Plaid-detected and user-created streams:

```swift
// In RecurringStreamRow, update the header to show source
HStack(spacing: 4) {
    Text(stream.frequencyDisplay)
    Text("•")
    Text("$\(stream.averageAmount, specifier: "%.2f")")
    if stream.status == "EARLY_DETECTION" {
        Text("•")
        Text("Early")
            .foregroundColor(.orange)
    }
    if stream.isManual {
        Text("•")
        Text("Manual")
            .foregroundColor(.blue)
    }
}
.font(.caption)
.foregroundColor(.secondary)

// In the expanded section, add delete button for manual streams
if isExpanded {
    Divider()

    VStack(spacing: 12) {
        // ... existing toggles ...

        if stream.isManual {
            Button(role: .destructive, action: {
                Task {
                    try? await budgetService.deleteManualStream(streamId: stream.id)
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Manual Stream")
                }
            }
        }
    }
}
```

### 10.5 Update Navigation

Add navigation link to `RecurringTransactionsView` in your budget/settings screen:

```swift
NavigationLink(destination: RecurringTransactionsView()) {
    HStack {
        Image(systemName: "repeat.circle")
        Text("Manage Recurring Transactions")
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
    }
}
```
