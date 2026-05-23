//
//  BabloLogoMark.swift
//  Bablo
//

import SwiftUI

struct BabloLogoMark: View {
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: theme.effects.isPopArt ? 2 : 0) {
            Text(theme.effects.isPopArt ? "BABLO" : "bablo")
                .font(wordmarkFont)
                .tracking(theme.effects.isPopArt ? 2 : -4)
                .foregroundStyle(theme.colors.textPrimary.color)
                .shadow(color: logoShadow, radius: 0, x: theme.effects.isPopArt ? 4 : 0, y: theme.effects.isPopArt ? 4 : 0)

            Text(theme.effects.isPopArt ? "!" : ".")
                .font(punctuationFont)
                .foregroundStyle(theme.effects.isPopArt ? theme.colors.danger.color : theme.colors.accentPressed.color)
                .rotationEffect(.degrees(theme.effects.isPopArt ? 8 : 0))
                .offset(y: theme.effects.isPopArt ? 4 : 0)
        }
        .accessibilityLabel("Bablo")
    }

    private var wordmarkFont: Font {
        theme.effects.isPopArt
        ? .system(size: 64, weight: .black, design: .rounded).italic()
        : .system(size: 46, weight: .black, design: .default)
    }

    private var punctuationFont: Font {
        theme.effects.isPopArt
        ? .system(size: 72, weight: .black, design: .rounded).italic()
        : .system(size: 46, weight: .black, design: .default)
    }

    private var logoShadow: Color {
        theme.effects.isPopArt ? theme.colors.accent.color : .clear
    }
}

#Preview("Logo Pop") {
    BabloLogoMark()
        .padding()
        .babloTheme(.pop)
}

#Preview("Logo Normal") {
    BabloLogoMark()
        .padding()
        .babloTheme(.normal)
}
