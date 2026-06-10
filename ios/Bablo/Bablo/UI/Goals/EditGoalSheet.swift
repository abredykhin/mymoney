//
//  EditGoalSheet.swift
//  Bablo
//
//  Pre-filled form for editing an existing goal's name, icon, target amount,
//  target date, and color. Calls GoalsService.updateSavingsGoal().
//

import SwiftUI

struct EditGoalSheet: View {
    let goal: GoalSummaryItem

    @EnvironmentObject private var goalsService: GoalsService
    @EnvironmentObject private var accountsService: AccountsService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.babloTheme) private var theme

    @State private var name: String
    @State private var selectedIcon: String
    @State private var targetAmountText: String
    @State private var monthlyContributionText: String
    @State private var fundingMode: GoalFundingMode
    @State private var linkedAccountId: Int?
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var selectedColor: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let iconOptions: [String] = [
        "✈️", "🏖️", "🏠", "🚗", "💻", "📱", "🎓", "💍",
        "🎮", "🏋️", "🌍", "🎸", "🐶", "👶", "🏄", "⛵",
        "🎯", "💰", "🔑", "🧳"
    ]

    init(goal: GoalSummaryItem) {
        self.goal = goal
        _name = State(initialValue: goal.name)
        _selectedIcon = State(initialValue: goal.categoryIcon)
        _targetAmountText = State(initialValue: "\(Int(goal.targetAmount))")
        _monthlyContributionText = State(initialValue: goal.monthlyContribution > 0 ? "\(Int(goal.monthlyContribution))" : "")
        _fundingMode = State(initialValue: GoalFundingMode(rawValue: goal.fundingMode) ?? .autoStash)
        _linkedAccountId = State(initialValue: goal.linkedAccountId)
        _selectedColor = State(initialValue: goal.color)

        if let etaStr = goal.etaDate {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            let date = fmt.date(from: etaStr) ?? Date()
            _hasTargetDate = State(initialValue: true)
            _targetDate = State(initialValue: date)
        } else {
            _hasTargetDate = State(initialValue: false)
            _targetDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // Icon picker
                    iconPickerSection

                    // Name
                    formSection(label: "GOAL NAME") {
                        TextField("e.g. Japan trip", text: $name)
                            .textFieldStyle(BabloTextFieldStyle())
                    }

                    // Target amount
                    formSection(label: "TARGET AMOUNT") {
                        HStack {
                            Text("$")
                                .font(theme.typography.body(size: 17, weight: .bold))
                                .foregroundStyle(theme.colors.textTertiary.color)
                            TextField("0", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                                .font(theme.typography.mono(size: 17, weight: .bold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                    }

                    fundingSection

                    // Target date
                    formSection(label: "TARGET DATE (OPTIONAL)") {
                        Toggle("Set a target date", isOn: $hasTargetDate)
                            .font(theme.typography.body(size: 15, weight: .semibold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .tint(theme.colors.accent.color)

                        if hasTargetDate {
                            DatePicker(
                                "Target date",
                                selection: $targetDate,
                                in: Date()...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(theme.colors.accent.color)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Color
                    formSection(label: "COLOR") {
                        GoalColorPicker(selectedColor: $selectedColor)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(theme.typography.body(size: 13))
                            .foregroundStyle(theme.colors.danger.color)
                            .padding(.horizontal, theme.metrics.screenPadding)
                    }

                    // Save button
                    Button {
                        saveChanges()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(theme.colors.accentInk.color)
                            } else {
                                Text("Save changes")
                                    .font(theme.typography.body(size: 16, weight: .bold))
                                    .foregroundStyle(theme.colors.accentInk.color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: theme.metrics.buttonHeight)
                        .background(theme.colors.accent.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, theme.metrics.screenPadding)
                }
                .padding(.vertical, 20)
            }
            .babloScreenBackground()
            .navigationTitle("Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasTargetDate)
        .task {
            try? await accountsService.refreshAccounts()
        }
    }

    // MARK: - Icon Picker

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ICON")
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)
                .padding(.horizontal, theme.metrics.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Text(icon)
                                .font(.system(size: 24))
                                .frame(width: 48, height: 48)
                                .background(selectedIcon == icon
                                    ? (Color(hex: selectedColor) ?? theme.colors.accent.color).opacity(0.2)
                                    : theme.colors.surfaceMuted.color)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    if selectedIcon == icon {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(hex: selectedColor) ?? theme.colors.accent.color, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.vertical, 4)
            }
        }
    }

    private var fundingSection: some View {
        formSection(label: "FUNDING") {
            Picker("Funding", selection: $fundingMode) {
                ForEach(GoalFundingMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("goals.edit.fundingMode")

            if fundingMode == .autoStash {
                HStack {
                    Text("$")
                        .font(theme.typography.body(size: 17, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                    TextField("0", text: $monthlyContributionText)
                        .keyboardType(.decimalPad)
                        .font(theme.typography.mono(size: 17, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))

                Text(autoStashImpactText)
                    .font(theme.typography.body(size: 12, weight: .medium))
                    .foregroundStyle(theme.colors.textTertiary.color)
            } else {
                Picker("Linked account", selection: linkedAccountBinding) {
                    Text("Choose account").tag(-1)
                    ForEach(linkableAccounts) { account in
                        Text(accountPickerTitle(account)).tag(account.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                .accessibilityIdentifier("goals.edit.linkedAccountPicker")

                Text("This goal uses the account balance as progress and removes that account from safe-to-spend.")
                    .font(theme.typography.body(size: 12, weight: .medium))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)
            content()
        }
        .padding(.horizontal, theme.metrics.screenPadding)
    }

    private func saveChanges() {
        guard let amount = Double(targetAmountText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Enter a valid dollar amount"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a goal name"
            return
        }

        let monthlyContribution = Double(monthlyContributionText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard monthlyContribution >= 0 else {
            errorMessage = "Enter a positive monthly amount"
            return
        }
        if fundingMode == .linked && linkedAccountId == nil {
            errorMessage = "Choose an account to link"
            return
        }

        errorMessage = nil
        isSaving = true

        let etaDateString: String? = hasTargetDate ? {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: targetDate)
        }() : nil

        Task {
            do {
                try await goalsService.updateSavingsGoal(
                    id: goal.id,
                    name: trimmedName,
                    targetAmount: amount,
                    etaDate: etaDateString,
                    categoryIcon: selectedIcon,
                    color: selectedColor,
                    monthlyContribution: monthlyContribution,
                    fundingMode: fundingMode,
                    linkedAccountId: fundingMode == .linked ? linkedAccountId : nil
                )
                dismiss()
            } catch {
                errorMessage = "Failed to save changes. Try again."
            }
            isSaving = false
        }
    }

    private var linkableAccounts: [BankAccount] {
        accountsService.visibleBanksWithAccounts
            .flatMap(\.accounts)
            .filter { $0.type.caseInsensitiveCompare("depository") == .orderedSame }
            .sorted { $0.displayName < $1.displayName }
    }

    private var linkedAccountBinding: Binding<Int> {
        Binding(
            get: { linkedAccountId ?? -1 },
            set: { linkedAccountId = $0 == -1 ? nil : $0 }
        )
    }

    private var autoStashImpactText: String {
        let monthlyContribution = Double(monthlyContributionText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard monthlyContribution > 0 else {
            return "We'll set this aside from your budget each month and hide it from safe-to-spend."
        }
        let impact = GoalFundingImpact(
            monthlyContribution: monthlyContribution,
            daysRemaining: daysRemainingInMonth,
            currentDailyPace: 0
        )
        return "This lowers safe-to-spend by \(formatCurrency(monthlyContribution))/mo, about \(formatCurrency(abs(impact.dailyPaceDelta)))/day this month."
    }

    private var daysRemainingInMonth: Int {
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let range = calendar.range(of: .day, in: .month, for: today)
        return max(1, (range?.count ?? 30) - day + 1)
    }

    private func accountPickerTitle(_ account: BankAccount) -> String {
        let mask = account.mask.map { " ·\($0)" } ?? ""
        return "\(account.displayName)\(mask) · \(formatCurrency(account.currentBalance))"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

#Preview {
    EditGoalSheet(goal: GoalsPreviewFixtures.goals[0])
        .environmentObject(GoalsService())
        .environmentObject(AccountsService())
}
