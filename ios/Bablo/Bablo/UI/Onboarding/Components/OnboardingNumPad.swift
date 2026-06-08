import SwiftUI

struct OnboardingNumPad: View {
    let onKey: (String) -> Void

    @Environment(\.babloTheme) private var theme

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        NumKey(label: key, theme: theme, onTap: { onKey(key) })
                    }
                }
            }
        }
    }
}

private struct NumKey: View {
    let label: String
    let theme: BabloResolvedTheme
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                    .fill(theme.colors.surface.color)
                    .shadow(
                        color: theme.effects.shadowColor.opacity(0.08),
                        radius: 4, x: 0, y: 2
                    )

                Group {
                    if label == "⌫" {
                        Image(systemName: "delete.backward")
                            .font(.system(size: 20, weight: .medium))
                    } else {
                        Text(label)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(theme.colors.textPrimary.color)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
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

#Preview {
    OnboardingNumPad(onKey: { _ in })
        .padding()
        .background(Color.gray.opacity(0.1))
}

