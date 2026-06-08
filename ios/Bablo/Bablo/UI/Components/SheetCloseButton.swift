import SwiftUI

struct SheetCloseButton: View {
    let theme: BabloResolvedTheme
    var showsBorder = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if theme.effects.isPopArt {
                    Rectangle()
                        .fill(theme.colors.surface.color)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Rectangle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                        .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                } else {
                    Circle()
                        .fill(theme.colors.surfaceMuted.color)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if showsBorder {
                                Circle()
                                    .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                            }
                        }
                }

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

#Preview {
    SheetCloseButton(theme: BabloTheme.normal.resolved(for: .light), action: {})
        .padding()
}
