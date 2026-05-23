//
//  BabloAuthProviderButton.swift
//  Bablo
//

import SwiftUI

enum BabloAuthProvider {
    case apple
    case google

    var title: String {
        switch self {
        case .apple:
            "Continue with Apple"
        case .google:
            "Continue with Google"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .apple:
            "auth.apple"
        case .google:
            "auth.google"
        }
    }
}

struct BabloAuthProviderButton: View {
    let provider: BabloAuthProvider
    let action: () -> Void
    @Environment(\.babloTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                providerIcon
                Text(provider.title)
            }
            .font(theme.effects.isPopArt
                  ? .system(size: 17, weight: .black, design: .rounded)
                  : .system(size: 16, weight: .bold, design: .default))
            .tracking(theme.effects.isPopArt ? 4 : 0)
            .textCase(theme.effects.isPopArt ? .uppercase : nil)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: theme.effects.isPopArt ? 58 : 50)
            .foregroundStyle(theme.colors.textPrimary.color)
            .background(theme.effects.isPopArt ? theme.colors.surfaceMuted.color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.effects.isPopArt ? 4 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.effects.isPopArt ? 4 : 22, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: theme.effects.isPopArt ? 2.5 : 1)
            }
            .shadow(color: theme.effects.isPopArt ? theme.effects.shadowColor : .clear, radius: 0, x: theme.effects.isPopArt ? 4 : 0, y: theme.effects.isPopArt ? 4 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(provider.accessibilityIdentifier)
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 22, weight: .semibold))
        case .google:
            GoogleLogoIcon(size: 22)
                .accessibilityHidden(true)
        }
    }
}

private struct GoogleLogoIcon: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let lw = w * 0.22
            let r = (w - lw) / 2
            let c = CGPoint(x: w / 2, y: h / 2)

            let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)
            let red    = Color(red: 0.918, green: 0.263, blue: 0.208)
            let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)
            let green  = Color(red: 0.204, green: 0.659, blue: 0.325)

            func arc(_ from: Double, _ to: Double, _ color: Color) {
                var path = Path()
                path.addArc(center: c, radius: r, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: true)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            }

            // Gap is at the right (0° = 3 o'clock). Going clockwise:
            arc(30,  80,  yellow)  // lower-right (4 o'clock → 5:40)
            arc(80,  180, green)   // bottom-left (5:40 → 9 o'clock)
            arc(180, 300, blue)    // left through top (9 o'clock → 1 o'clock)
            arc(300, 330, red)     // upper-right (1 o'clock → 2 o'clock)

            // Blue horizontal crossbar
            var bar = Path()
            bar.move(to: CGPoint(x: w / 2, y: h / 2))
            bar.addLine(to: CGPoint(x: w - lw / 2, y: h / 2))
            context.stroke(bar, with: .color(blue), style: StrokeStyle(lineWidth: lw, lineCap: .square))
        }
        .frame(width: size, height: size)
    }
}

#Preview("Apple Pop") {
    BabloAuthProviderButton(provider: .apple, action: {})
        .padding()
        .babloTheme(.pop)
}

#Preview("Apple Normal") {
    BabloAuthProviderButton(provider: .apple, action: {})
        .padding()
        .babloTheme(.normal)
}
