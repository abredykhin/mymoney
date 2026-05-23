import SwiftUI

struct BabloProgressPills: View {
    let total: Int
    let currentIndex: Int

    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: theme.effects.isPopArt ? 8 : 6) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= currentIndex ? theme.colors.textPrimary.color : theme.colors.surfaceMuted.color)
                    .overlay {
                        if theme.effects.isPopArt {
                            Capsule(style: .continuous)
                                .stroke(theme.colors.line.color, lineWidth: 1.5)
                        }
                    }
                    .frame(height: theme.effects.isPopArt ? 8 : 4)
                    .frame(maxWidth: index == currentIndex ? 64 : 44)
            }
        }
        .animation(.easeOut(duration: 0.22), value: currentIndex)
    }
}
