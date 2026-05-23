import SwiftUI

private struct BabloThemeVariantKey: EnvironmentKey {
    static let defaultValue: BabloTheme = .normal
}

private struct BabloResolvedThemeKey: EnvironmentKey {
    static let defaultValue: BabloResolvedTheme = BabloTheme.normal.resolved(for: .light)
}

extension EnvironmentValues {
    var babloThemeVariant: BabloTheme {
        get { self[BabloThemeVariantKey.self] }
        set { self[BabloThemeVariantKey.self] = newValue }
    }

    var babloTheme: BabloResolvedTheme {
        get { self[BabloResolvedThemeKey.self] }
        set { self[BabloResolvedThemeKey.self] = newValue }
    }
}

struct BabloThemeProvider<Content: View>: View {
    let theme: BabloTheme
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .environment(\.babloThemeVariant, theme)
            .environment(\.babloTheme, theme.resolved(for: colorScheme))
    }
}

extension View {
    func babloTheme(_ theme: BabloTheme) -> some View {
        BabloThemeProvider(theme: theme) {
            self
        }
    }
}
