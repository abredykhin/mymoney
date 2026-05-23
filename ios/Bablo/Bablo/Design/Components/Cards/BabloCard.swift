import SwiftUI

enum BabloCardTone {
    case surface
    case muted
    case accent
}

struct BabloCard: ViewModifier {
    let tone: BabloCardTone
    let padding: CGFloat?

    @Environment(\.babloTheme) private var theme

    init(tone: BabloCardTone = .surface, padding: CGFloat? = nil) {
        self.tone = tone
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding ?? theme.metrics.cardPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: theme.metrics.borderWidth)
            }
            .shadow(
                color: shadowColor,
                radius: theme.effects.shadowRadius,
                x: theme.effects.shadowX,
                y: theme.effects.shadowY
            )
    }

    private var background: Color {
        switch tone {
        case .surface:
            return theme.colors.surface.color
        case .muted:
            return theme.colors.surfaceMuted.color
        case .accent:
            return theme.colors.accent.color
        }
    }

    private var borderColor: Color {
        theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color
    }

    private var shadowColor: Color {
        theme.effects.isPopArt ? theme.effects.shadowColor : theme.effects.shadowColor.opacity(0.04)
    }
}

extension View {
    func babloCard(tone: BabloCardTone = .surface, padding: CGFloat? = nil) -> some View {
        modifier(BabloCard(tone: tone, padding: padding))
    }
}
