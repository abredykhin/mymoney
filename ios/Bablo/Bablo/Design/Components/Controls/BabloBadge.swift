import SwiftUI

struct BabloBadge: View {
    let title: String
    var tone: BabloBadgeTone = .accent
    
    @Environment(\.babloTheme) private var theme
    
    enum BabloBadgeTone: Equatable {
        case accent
        case success
        case warning
        case info
        case custom(Color, Color) // Background, Text
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        Text(title)
            .font(theme.typography.body(size: 9, weight: .black))
            .tracking(isPopArt ? 1.0 : 0)
            .textCase(.uppercase)
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: isPopArt ? 2 : 4, style: .continuous))
            .overlay {
                if isPopArt {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.0)
                }
            }
    }
    
    private var textColor: Color {
        switch tone {
        case .accent:
            return theme.colors.textSecondary.color
        case .success:
            return theme.colors.success.color
        case .warning:
            return theme.colors.warning.color
        case .info:
            return theme.colors.info.color
        case .custom(_, let text):
            return text
        }
    }
    
    private var backgroundColor: Color {
        switch tone {
        case .accent:
            // Use subtle yellow/accent background in normal theme, or solid accent in Pop theme
            return theme.colors.accent.color.opacity(theme.effects.isPopArt ? 1.0 : 0.15)
        case .success:
            return theme.colors.success.color.opacity(0.12)
        case .warning:
            return theme.colors.warning.color.opacity(0.12)
        case .info:
            return theme.colors.info.color.opacity(0.12)
        case .custom(let bg, _):
            return bg
        }
    }
}
