import SwiftUI

struct BabloScreenBackground<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.babloTheme) private var theme

    var body: some View {
        ZStack {
            theme.colors.appBackground.color
                .ignoresSafeArea()

            if theme.effects.isPopArt {
                HalftoneDots(color: theme.colors.line.color.opacity(theme.effects.halftoneDotOpacity))
                    .ignoresSafeArea()
            }

            content
        }
    }
}

private struct HalftoneDots: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            let radius: CGFloat = 1
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

extension View {
    func babloScreenBackground() -> some View {
        BabloScreenBackground {
            self
        }
    }
}
