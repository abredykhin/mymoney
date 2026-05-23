import SwiftUI

struct BabloSegmentedControl<Selection: Hashable>: View {
    struct Item: Identifiable {
        let id: Selection
        let title: String
    }

    let items: [Item]
    @Binding var selection: Selection
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: theme.effects.isPopArt ? 0 : 4) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    Text(item.title)
                        .font(theme.typography.body(size: 13, weight: .bold))
                        .tracking(theme.effects.isPopArt ? theme.typography.labelTracking : 0)
                        .textCase(theme.effects.isPopArt ? .uppercase : nil)
                        .foregroundStyle(foreground(for: item))
                        .frame(minWidth: 62, minHeight: 36)
                        .padding(.horizontal, 8)
                        .background(background(for: item))
                        .clipShape(RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.effects.isPopArt ? 0 : 4)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.effects.isPopArt ? theme.metrics.borderWidth : theme.metrics.borderWidth)
        }
    }

    private var segmentCornerRadius: CGFloat {
        theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999
    }

    private func foreground(for item: Item) -> Color {
        guard item.id == selection else { return theme.colors.textSecondary.color }
        return theme.effects.isPopArt ? theme.colors.surface.color : theme.colors.textPrimary.color
    }

    private func background(for item: Item) -> Color {
        guard item.id == selection else { return .clear }
        return theme.effects.isPopArt ? theme.colors.textPrimary.color : theme.colors.surface.color
    }
}
