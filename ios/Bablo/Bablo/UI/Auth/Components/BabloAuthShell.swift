//
//  BabloAuthShell.swift
//  Bablo
//

import SwiftUI

struct BabloAuthShell<Content: View, BottomBar: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let bottomBar: BottomBar
    @Environment(\.babloTheme) private var theme

    var body: some View {
        BabloScreenBackground {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        content
                    }
                    .padding(.horizontal, theme.metrics.screenPadding + 12)
                    .padding(.top, 38)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)

                bottomBar
                    .padding(.horizontal, theme.metrics.screenPadding + 12)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                    .background(theme.colors.appBackground.color.opacity(0.94))
            }
        }
    }
}

#Preview("Auth Shell Pop") {
    BabloAuthShell {
        BabloLogoMark()
        Text("Welcome back.")
    } bottomBar: {
        Button("Continue") {}
            .buttonStyle(.babloPrimary)
    }
    .babloTheme(.pop)
}

#Preview("Auth Shell Normal") {
    BabloAuthShell {
        BabloLogoMark()
        Text("Welcome back.")
    } bottomBar: {
        Button("Continue") {}
            .buttonStyle(.babloPrimary)
    }
    .babloTheme(.normal)
}
