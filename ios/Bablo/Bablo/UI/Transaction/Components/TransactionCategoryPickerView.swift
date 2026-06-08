import SwiftUI

struct TransactionCategoryPickerView: View {
    @Environment(\.babloTheme) private var theme

    let transactionName: String
    @Binding var selectedCategory: FlexibleSpendingCategory?
    let availableCategories: [FlexibleSpendingCategory]
    let isSavingCategory: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryGrid
            saveFooter
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CATEGORIZE")
                    .font(theme.typography.mono(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(theme.colors.textSecondary.color)
                Text(transactionName)
                    .font(theme.typography.title(size: 21, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .frame(width: 38, height: 38)
                    .background(theme.colors.surfaceMuted.color)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var categoryGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(availableCategories) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var saveFooter: some View {
        VStack(spacing: 12) {
            Divider().overlay(theme.colors.line.color)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEW CATEGORY")
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                    Text(newCategoryText)
                        .font(theme.typography.body(size: 14, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if isSavingCategory {
                            ProgressView().tint(theme.colors.surface.color)
                        } else {
                            Text("Save")
                            Image(systemName: "checkmark")
                        }
                    }
                    .font(theme.typography.body(size: 16, weight: .black))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 22)
                    .frame(height: 50)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedCategory == nil || isSavingCategory)
                .opacity(selectedCategory == nil ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(theme.colors.appBackground.color)
    }

    private func categoryCard(_ category: FlexibleSpendingCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Text(category.emoji)
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(category.detailTint.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.displayName)
                        .font(theme.typography.body(size: 14, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(category.subtitle)
                        .font(theme.typography.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 2)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(theme.colors.surface.color)
                        .frame(width: 24, height: 24)
                        .background(theme.colors.accent.color)
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .frame(minHeight: 74)
            .background(isSelected ? theme.colors.accent.color.opacity(0.16) : theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? theme.colors.accent.color : theme.colors.line.color,
                        lineWidth: isSelected ? 1.7 : theme.metrics.borderWidth
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var newCategoryText: String {
        guard let selectedCategory else { return "Choose a category" }
        return "\(selectedCategory.emoji) \(selectedCategory.displayName) · \(selectedCategory.subtitle)"
    }
}

#Preview {
    TransactionCategoryPickerView(
        transactionName: "Trader Joe's",
        selectedCategory: .constant(.groceries),
        availableCategories: FlexibleSpendingCategory.allCases,
        isSavingCategory: false,
        onDismiss: {},
        onSave: {}
    )
}

