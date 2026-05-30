//
//  AddGoalSheet.swift
//  Bablo
//
//  Sheet for creating a new savings goal. Collects name, icon (emoji picker),
//  target amount, optional target date, and color swatch.
//

import SwiftUI

struct AddGoalSheet: View {
    @EnvironmentObject private var goalsService: GoalsService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.babloTheme) private var theme

    @State private var name: String = ""
    @State private var selectedIcon: String = "✈️"
    @State private var targetAmountText: String = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var selectedColor: String = GoalColorOption.blue.hex
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let iconOptions: [String] = [
        "✈️", "🏖️", "🏠", "🚗", "💻", "📱", "🎓", "💍",
        "🎮", "🏋️", "🌍", "🎸", "🐶", "👶", "🏄", "⛵",
        "🎯", "💰", "🔑", "🧳"
    ]

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
                            .accessibilityIdentifier("goals.add.nameField")
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
                                .accessibilityIdentifier("goals.add.amountField")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
                    }

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

                    // Color picker
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
                        saveGoal()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(theme.colors.accentInk.color)
                            } else {
                                Text("Create goal")
                                    .font(theme.typography.body(size: 16, weight: .bold))
                                    .foregroundStyle(theme.colors.accentInk.color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: theme.metrics.buttonHeight)
                        .background(theme.colors.accent.color)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
                        .overlay {
                            if theme.effects.isPopArt {
                                RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous)
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || targetAmountText.isEmpty)
                    .padding(.horizontal, theme.metrics.screenPadding)
                    .accessibilityIdentifier("goals.add.createButton")
                }
                .padding(.vertical, 20)
            }
            .babloScreenBackground()
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
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

    // MARK: - Form Section Helper

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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasTargetDate)
    }

    // MARK: - Save

    private func saveGoal() {
        guard let amount = Double(targetAmountText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Enter a valid dollar amount"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a goal name"
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
                _ = try await goalsService.createSavingsGoal(
                    name: trimmedName,
                    targetAmount: amount,
                    etaDate: etaDateString,
                    categoryIcon: selectedIcon,
                    color: selectedColor
                )
                dismiss()
            } catch {
                errorMessage = "Failed to create goal. Try again."
            }
            isSaving = false
        }
    }
}

// MARK: - Color Picker

enum GoalColorOption: String, CaseIterable {
    case blue   = "#4A9EFF"
    case green  = "#34D399"
    case orange = "#FB923C"
    case pink   = "#F472B6"
    case purple = "#A78BFA"
    case lime   = "#A9F236"

    var hex: String { rawValue }
    var label: String { rawValue }
}

struct GoalColorPicker: View {
    @Binding var selectedColor: String
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GoalColorOption.allCases, id: \.rawValue) { option in
                Button {
                    selectedColor = option.hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: option.hex) ?? .gray)
                            .frame(width: 36, height: 36)
                        if selectedColor == option.hex {
                            Circle()
                                .stroke(theme.colors.textPrimary.color, lineWidth: 2.5)
                                .frame(width: 42, height: 42)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(option.rawValue)")
            }
        }
    }
}

#Preview("Add Goal Sheet · Normal") {
    AddGoalSheet()
        .environmentObject(GoalsService())
        .babloTheme(.normal)
}

#Preview("Add Goal Sheet · Pop") {
    AddGoalSheet()
        .environmentObject(GoalsService())
        .babloTheme(.pop)
}
