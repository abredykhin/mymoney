import SwiftUI

struct BabloChip: View {
    let title: String
    var icon: Image?
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.babloTheme) private var theme

    init(
        _ title: String,
        icon: Image? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                Text(title)
            }
            .font(theme.typography.body(size: theme.effects.isPopArt ? 14 : 13, weight: .bold))
            .tracking(theme.effects.isPopArt ? theme.typography.labelTracking : 0)
            .textCase(theme.effects.isPopArt ? .uppercase : nil)
            .foregroundStyle(foreground)
            .padding(.horizontal, theme.effects.isPopArt ? 13 : 12)
            .frame(minHeight: theme.effects.isPopArt ? 38 : 34)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 999, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.effects.isPopArt ? 2 : theme.metrics.borderWidth)
            }
            .shadow(
                color: theme.effects.isPopArt ? theme.effects.shadowColor : .clear,
                radius: 0,
                x: theme.effects.isPopArt ? 2 : 0,
                y: theme.effects.isPopArt ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if theme.effects.isPopArt {
            return theme.colors.textPrimary.color
        }
        return isSelected ? theme.colors.surface.color : theme.colors.textPrimary.color
    }

    private var background: Color {
        if isSelected {
            return theme.effects.isPopArt ? theme.colors.accent.color : theme.colors.textPrimary.color
        }
        return theme.colors.surfaceMuted.color
    }
}
