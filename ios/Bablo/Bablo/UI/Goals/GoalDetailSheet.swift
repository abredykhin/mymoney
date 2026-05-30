//
//  GoalDetailSheet.swift
//  Bablo
//
//  Detail sheet shown when tapping a goal row.
//  Shows goal progress, deposit log field, deposit history, and edit/delete actions.
//

import SwiftUI

struct GoalDetailSheet: View {
    let goal: GoalSummaryItem

    @EnvironmentObject private var goalsService: GoalsService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.babloTheme) private var theme

    @State private var depositAmount: String = ""
    @State private var deposits: [SavingsDeposit] = []
    @State private var isLoadingDeposits = false
    @State private var isAddingDeposit = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Goal header card
                    goalHeaderCard
                        .padding(.horizontal, theme.metrics.screenPadding)
                        .padding(.top, 8)

                    // Add deposit section
                    addDepositSection
                        .padding(.horizontal, theme.metrics.screenPadding)

                    // Deposit history
                    if !deposits.isEmpty {
                        depositHistorySection
                            .padding(.horizontal, theme.metrics.screenPadding)
                    }

                    // Destructive action
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete goal", systemImage: "trash")
                            .font(theme.typography.body(size: 15, weight: .semibold))
                            .foregroundStyle(theme.colors.danger.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.colors.surfaceMuted.color)
                            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, theme.metrics.screenPadding)
                    .accessibilityIdentifier("goals.detail.deleteButton")
                }
                .padding(.bottom, 40)
            }
            .babloScreenBackground()
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(theme.typography.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showEditSheet = true }
                        .font(theme.typography.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .accessibilityIdentifier("goals.detail.editButton")
                }
            }
            .task {
                await loadDeposits()
            }
            .alert("Delete \"\(goal.name)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await goalsService.deleteSavingsGoal(goalId: goal.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the goal and all its deposit history.")
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                Task {
                    try? await goalsService.fetchGoalsSummary()
                    await loadDeposits()
                }
            }) {
                EditGoalSheet(goal: goal)
                    .environmentObject(goalsService)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Goal Header Card

    private var goalHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(goal.categoryIcon)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(theme.typography.title(size: 20, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Text(formatCurrency(goal.currentAmount) + " of " + formatCurrency(goal.targetAmount))
                        .font(theme.typography.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }

            BabloProgressBar(
                progress: goal.progressPercent,
                height: 10,
                tintColor: Color(hex: goal.color) ?? theme.colors.accent.color
            )

            HStack {
                Text(goal.isFunded ? "Smashed it 🎉" : etaStatusText)
                    .font(theme.typography.body(size: 13, weight: .semibold))
                    .foregroundStyle(goal.isFunded ? theme.colors.success.color : statusColor)

                Spacer()

                Text("\(Int(goal.pct))%")
                    .font(theme.typography.mono(size: 13, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .babloCard(tone: .surface)
    }

    // MARK: - Add Deposit Section

    private var addDepositSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOG SAVINGS")
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)

            HStack(spacing: 12) {
                HStack {
                    Text("$")
                        .font(theme.typography.body(size: 17, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                    TextField("0", text: $depositAmount)
                        .keyboardType(.decimalPad)
                        .font(theme.typography.mono(size: 17, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .accessibilityIdentifier("goals.detail.depositField")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))

                Button {
                    submitDeposit()
                } label: {
                    Group {
                        if isAddingDeposit {
                            ProgressView()
                                .tint(theme.colors.surface.color)
                        } else {
                            Text("Log savings")
                                .font(theme.typography.body(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(theme.colors.accentInk.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.colors.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAddingDeposit || depositAmount.isEmpty)
                .accessibilityIdentifier("goals.detail.logButton")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(theme.typography.body(size: 13))
                    .foregroundStyle(theme.colors.danger.color)
            }
        }
    }

    // MARK: - Deposit History

    private var depositHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEPOSIT HISTORY")
                .font(theme.typography.mono(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)

            VStack(spacing: 0) {
                ForEach(Array(deposits.enumerated()), id: \.element.id) { index, deposit in
                    HStack {
                        Text(formattedDepositDate(deposit.depositDate))
                            .font(theme.typography.body(size: 14, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary.color)
                        Spacer()
                        Text("+\(formatCurrency(deposit.amount))")
                            .font(theme.typography.mono(size: 14, weight: .bold))
                            .foregroundStyle(theme.colors.success.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < deposits.count - 1 {
                        Rectangle()
                            .fill(theme.colors.line.color)
                            .frame(height: theme.metrics.borderWidth)
                    }
                }
            }
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
            }
        }
    }

    // MARK: - Helpers

    private func submitDeposit() {
        guard let amount = Double(depositAmount.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            errorMessage = "Enter a valid amount"
            return
        }
        errorMessage = nil
        isAddingDeposit = true

        Task {
            do {
                _ = try await goalsService.addDeposit(goalId: goal.id, amount: amount)
                depositAmount = ""
                await loadDeposits()
            } catch {
                errorMessage = "Failed to log deposit. Try again."
            }
            isAddingDeposit = false
        }
    }

    private func loadDeposits() async {
        isLoadingDeposits = true
        deposits = (try? await goalsService.fetchDeposits(goalId: goal.id)) ?? []
        isLoadingDeposits = false
    }

    private var etaStatusText: String {
        let status = goal.statusLabel.capitalized
        if let etaStr = goal.etaDate {
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withFullDate]
            if let date = isoFmt.date(from: etaStr) {
                let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
                return "ETA \(fmt.string(from: date)) · \(status)"
            }
        }
        return status
    }

    private var statusColor: Color {
        switch goal.statusLabel {
        case "on track": return theme.colors.info.color
        case "almost":   return theme.colors.warning.color
        case "at risk":  return theme.colors.danger.color
        default:         return theme.colors.textTertiary.color
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    private func formattedDepositDate(_ dateString: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        if let date = isoFmt.date(from: dateString) {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            return fmt.string(from: date)
        }
        return dateString
    }
}
