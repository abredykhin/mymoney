import SwiftUI

struct OnboardingFixedExpensesView: View {
    /// Amounts keyed by category; 0 means "Skip" (not tracking)
    @State private var amounts: [FixedExpenseCategory: Int]

    var onNext: ([FixedExpenseEntry]) -> Void

    @Environment(\.babloTheme) private var theme

    init(
        initialAmounts: [FixedExpenseCategory: Int] = Self.emptyAmounts,
        onNext: @escaping ([FixedExpenseEntry]) -> Void
    ) {
        _amounts = State(initialValue: initialAmounts)
        self.onNext = onNext
    }

    private var trackedEntries: [FixedExpenseEntry] {
        FixedExpenseCategory.allCases
            .filter { (amounts[$0] ?? 0) > 0 }
            .map { FixedExpenseEntry(category: $0, amount: amounts[$0]!) }
    }

    private var lockedTotal: Int {
        trackedEntries.reduce(0) { $0 + $1.amount }
    }

    private static var emptyAmounts: [FixedExpenseCategory: Int] {
        var amounts: [FixedExpenseCategory: Int] = [:]
        for category in FixedExpenseCategory.allCases {
            amounts[category] = 0
        }
        return amounts
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("THE NON-NEGOTIABLES")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(theme.typography.labelTracking)
                        .foregroundStyle(theme.colors.textSecondary.color)

                    Text("What's locked in?")
                        .font(theme.typography.title(size: 34, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)

                    Text("The same bills every month — rent, phone, that gym you forgot about.")
                        .font(theme.typography.body(size: 15))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                Spacer()
                Text("$$$")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.top, 4)
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 28)

            // Summary card
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LOCKED IN / MONTH")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(theme.typography.labelTracking)
                        .foregroundStyle(theme.colors.textSecondary.color)
                    Text("\(trackedEntries.count) bill\(trackedEntries.count == 1 ? "" : "s") · auto-tracked")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textTertiary.color)
                }
                Spacer()
                Text(lockedTotal, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: lockedTotal)
            }
            .padding(18)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 16)

            // Category rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(FixedExpenseCategory.allCases) { cat in
                        CategoryRow(
                            category: cat,
                            amount: Binding(
                                get: { amounts[cat] ?? 0 },
                                set: { amounts[cat] = $0 }
                            ),
                            theme: theme
                        )

                        if cat != FixedExpenseCategory.allCases.last {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // CTA
            OnboardingCTAButton(label: "Next") { onNext(trackedEntries) }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Category row

private struct CategoryRow: View {
    let category: FixedExpenseCategory
    @Binding var amount: Int
    let theme: BabloResolvedTheme

    var isTracking: Bool { amount > 0 }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Text(category.emoji)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(theme.colors.surfaceMuted.color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                Text(isTracking ? "Tracking" : "Skip")
                    .font(.system(size: 12))
                    .foregroundStyle(isTracking
                        ? (Color(hex: "#078A2E") ?? .green)
                        : theme.colors.textTertiary.color
                    )
            }

            Spacer()

            if isTracking {
                OnboardingAmountStepper(amount: $amount)
            } else {
                Button("Add") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        amount = category.suggestedDefault
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview("Fixed Expenses - Empty") {
    OnboardingFixedExpensesView(onNext: { _ in })
        .background(Color(hex: "#F8F5EF"))
}

#if DEBUG
#Preview("Fixed Expenses - Prefilled") {
    OnboardingFixedExpensesView(
        initialAmounts: .onboardingPreviewPrefilled,
        onNext: { _ in }
    )
    .background(Color(hex: "#F8F5EF"))
}
#endif
