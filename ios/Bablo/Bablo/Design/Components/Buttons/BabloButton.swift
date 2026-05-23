import SwiftUI

enum BabloButtonProminence {
    case primary
    case secondary
    case ghost
    case destructive
}

struct BabloButtonStyle: ButtonStyle {
    let prominence: BabloButtonProminence
    let isFullWidth: Bool

    @Environment(\.babloTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    init(_ prominence: BabloButtonProminence = .primary, isFullWidth: Bool = true) {
        self.prominence = prominence
        self.isFullWidth = isFullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(labelFont)
            .tracking(theme.typography.isUppercaseDisplay ? theme.typography.labelTracking : 0)
            .textCase(theme.typography.isUppercaseDisplay ? .uppercase : nil)
            .foregroundStyle(foreground)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: theme.metrics.buttonHeight)
            .padding(.horizontal, 22)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
            .overlay(border)
            .shadow(
                color: shadowColor(for: configuration),
                radius: theme.effects.shadowRadius,
                x: shadowX(for: configuration),
                y: shadowY(for: configuration)
            )
            .scaleEffect(configuration.isPressed ? theme.effects.pressedScale : 1)
            .offset(configuration.isPressed ? theme.effects.pressedOffset : .zero)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var labelFont: Font {
        theme.typography.body(size: theme.effects.isPopArt ? 18 : 16, weight: .bold)
    }

    private var foreground: Color {
        switch prominence {
        case .primary:
            return theme.effects.isPopArt ? theme.colors.surface.color : theme.colors.surface.color
        case .secondary, .ghost:
            return theme.colors.textPrimary.color
        case .destructive:
            return theme.colors.surface.color
        }
    }

    private var background: Color {
        switch prominence {
        case .primary:
            return theme.colors.textPrimary.color
        case .secondary:
            return theme.colors.surfaceMuted.color
        case .ghost:
            return .clear
        case .destructive:
            return theme.colors.danger.color
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        switch prominence {
        case .primary, .destructive:
            return theme.effects.isPopArt ? theme.colors.lineStrong.color : .clear
        case .secondary, .ghost:
            return theme.colors.line.color
        }
    }

    private var borderWidth: CGFloat {
        switch prominence {
        case .ghost:
            return theme.effects.isPopArt ? theme.metrics.borderWidth : 0
        default:
            return theme.effects.isPopArt ? theme.metrics.borderWidth : theme.metrics.borderWidth
        }
    }

    private func shadowColor(for configuration: Configuration) -> Color {
        guard theme.effects.isPopArt || prominence != .ghost else { return .clear }
        let opacity = theme.effects.isPopArt ? 1.0 : 0.06
        return theme.effects.shadowColor.opacity(configuration.isPressed ? opacity * 0.7 : opacity)
    }

    private func shadowX(for configuration: Configuration) -> CGFloat {
        guard theme.effects.isPopArt else { return 0 }
        return configuration.isPressed ? 2 : theme.effects.shadowX
    }

    private func shadowY(for configuration: Configuration) -> CGFloat {
        guard theme.effects.isPopArt else { return 4 }
        return configuration.isPressed ? 2 : theme.effects.shadowY
    }
}

extension ButtonStyle where Self == BabloButtonStyle {
    static var babloPrimary: BabloButtonStyle { BabloButtonStyle(.primary) }
    static var babloSecondary: BabloButtonStyle { BabloButtonStyle(.secondary) }
    static var babloGhost: BabloButtonStyle { BabloButtonStyle(.ghost, isFullWidth: false) }
    static var babloDestructive: BabloButtonStyle { BabloButtonStyle(.destructive) }
}
