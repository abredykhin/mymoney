import SwiftUI

struct BabloProgressBar: View {
    let progress: Double // Range: 0.0 to 1.0
    var height: CGFloat = 8
    var tintColor: Color? = nil

    @Environment(\.babloTheme) private var theme

    var body: some View {
        let activeTint = tintColor ?? theme.colors.accent.color
        let isPopArt = theme.effects.isPopArt

        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(0, min(width, width * CGFloat(progress)))

            ZStack(alignment: .leading) {
                // Background Track
                if isPopArt {
                    Rectangle()
                        .fill(theme.colors.surface.color)
                        .overlay {
                            Rectangle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                        }
                } else {
                    Capsule(style: .continuous)
                        .fill(theme.colors.surfaceMuted.color)
                }

                // Progress Fill
                if isPopArt {
                    Rectangle()
                        .fill(activeTint)
                        .frame(width: fillWidth)
                        .overlay(alignment: .trailing) {
                            if fillWidth > 0 && fillWidth < width {
                                Rectangle()
                                    .fill(theme.colors.lineStrong.color)
                                    .frame(width: theme.metrics.borderWidth)
                            }
                        }
                } else {
                    Capsule(style: .continuous)
                        .fill(activeTint)
                        .frame(width: fillWidth)
                }
            }
            .clipShape(isPopArt ? AnyShape(Rectangle()) : AnyShape(Capsule(style: .continuous)))
        }
        .frame(height: height)
    }
}

// Helper Shape Wrapper to handle conditional clipping
private struct AnyShape: Shape {
    private let path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        self.path = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

#Preview("Progress Normal") {
    VStack(spacing: 20) {
        BabloProgressBar(progress: 0.35)
        BabloProgressBar(progress: 0.75, height: 12)
    }
    .padding()
    .babloTheme(.normal)
}

#Preview("Progress Pop") {
    VStack(spacing: 20) {
        BabloProgressBar(progress: 0.35)
        BabloProgressBar(progress: 0.75, height: 12)
    }
    .padding()
    .babloTheme(.pop)
}
