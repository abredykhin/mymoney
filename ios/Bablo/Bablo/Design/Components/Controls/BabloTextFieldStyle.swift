import SwiftUI

struct BabloTextFieldStyle: TextFieldStyle {
    @Environment(\.babloTheme) private var theme
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .font(.system(size: theme.effects.isPopArt ? 20 : 17, weight: .medium, design: theme.effects.isPopArt ? .rounded : .default))
            .foregroundStyle(theme.colors.textPrimary.color)
            .padding(.horizontal, 18)
            .frame(minHeight: theme.effects.isPopArt ? 62 : 52)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? 4 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.effects.isPopArt ? 4 : 22, style: .continuous)
                    .stroke(
                        isFocused ? theme.colors.textPrimary.color : theme.colors.line.color,
                        lineWidth: theme.effects.isPopArt ? theme.metrics.borderWidth : theme.metrics.borderWidth
                    )
            }
            .shadow(
                color: theme.effects.isPopArt ? focusedPopShadow : .clear,
                radius: 0,
                x: theme.effects.isPopArt ? 3 : 0,
                y: theme.effects.isPopArt ? 3 : 0
            )
    }

    private var focusedPopShadow: Color {
        isFocused ? theme.colors.accent.color : theme.effects.shadowColor
    }
}

extension TextFieldStyle where Self == BabloTextFieldStyle {
    static var bablo: BabloTextFieldStyle { BabloTextFieldStyle() }
}
