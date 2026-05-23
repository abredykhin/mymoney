import SwiftUI

struct OnboardingCategoriesView: View {
    var onContinue: ([FlexibleSpendingCategory]) -> Void

    @State private var selected: Set<FlexibleSpendingCategory>
    @Environment(\.babloTheme) private var theme

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(
        initialSelected: Set<FlexibleSpendingCategory> = [],
        onContinue: @escaping ([FlexibleSpendingCategory]) -> Void
    ) {
        _selected = State(initialValue: initialSelected)
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("THE FUN MONEY")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(theme.typography.labelTracking)
                    .foregroundStyle(theme.colors.textSecondary.color)

                Text("Where does the rest go?")
                    .font(theme.typography.title(size: 34, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text("Pick the flexible categories you want to keep an eye on.")
                    .font(theme.typography.body(size: 15))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 28)

            // Selection counter + clear
            HStack {
                Text("\(selected.count) of \(FlexibleSpendingCategory.allCases.count) selected")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.textTertiary.color)

                Spacer()

                if !selected.isEmpty {
                    Button("Clear") {
                        withAnimation(.easeOut(duration: 0.2)) { selected.removeAll() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 14)
            .animation(.easeOut(duration: 0.15), value: selected.isEmpty)

            // Category grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FlexibleSpendingCategory.allCases) { cat in
                        CategoryCard(
                            category: cat,
                            isSelected: selected.contains(cat),
                            theme: theme
                        ) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                if selected.contains(cat) {
                                    selected.remove(cat)
                                } else {
                                    selected.insert(cat)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // CTA
            OnboardingCTAButton(label: "Continue") {
                onContinue(Array(selected))
            }
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: FlexibleSpendingCategory
    let isSelected: Bool
    let theme: BabloResolvedTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.emoji)
                        .font(.system(size: 30))

                    Spacer()

                    Text(category.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected
                            ? theme.colors.accentInk.color
                            : theme.colors.textPrimary.color
                        )

                    Text(category.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected
                            ? theme.colors.accentDeep.color
                            : theme.colors.textSecondary.color
                        )
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .frame(height: 130)
                .background(
                    isSelected
                        ? theme.colors.accent.color
                        : theme.colors.surface.color
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .shadow(
                    color: theme.effects.shadowColor.opacity(isSelected ? 0 : 0.06),
                    radius: 6, x: 0, y: 2
                )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.accentInk.color)
                        .padding(10)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96))
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Categories - Empty") {
    OnboardingCategoriesView(onContinue: { _ in })
        .background(Color(hex: "#F8F5EF"))
}

#if DEBUG
#Preview("Categories - Selected") {
    OnboardingCategoriesView(
        initialSelected: .onboardingPreviewSelected,
        onContinue: { _ in }
    )
    .background(Color(hex: "#F8F5EF"))
}
#endif
