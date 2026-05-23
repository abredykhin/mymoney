//
//  BabloAuthDivider.swift
//  Bablo
//

import SwiftUI

struct BabloAuthDivider: View {
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(theme.colors.line.color)
                .frame(height: theme.effects.isPopArt ? 2 : 1)

            Text("OR EMAIL")
                .font(theme.effects.isPopArt
                      ? .system(size: 13, weight: .black, design: .rounded)
                      : .system(size: 12, weight: .bold, design: .default))
                .tracking(theme.effects.isPopArt ? 4 : 5)
                .foregroundStyle(theme.effects.isPopArt ? theme.colors.textPrimary.color : theme.colors.textTertiary.color)
                .lineLimit(1)
                .fixedSize()

            Rectangle()
                .fill(theme.colors.line.color)
                .frame(height: theme.effects.isPopArt ? 2 : 1)
        }
    }
}

#Preview("Divider Pop") {
    BabloAuthDivider()
        .padding()
        .babloTheme(.pop)
}

#Preview("Divider Normal") {
    BabloAuthDivider()
        .padding()
        .babloTheme(.normal)
}
