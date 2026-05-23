//
//  DesignSystemTests.swift
//  BabloTests
//

import Testing
import SwiftUI
@testable import Bablo

struct DesignSystemTests {
    @Test func normalThemeUsesWarmPaperPaletteInLightMode() {
        let theme = BabloTheme.normal.resolved(for: .light)

        #expect(theme.colors.appBackground.hex == "#F8F5EF")
        #expect(theme.colors.surface.hex == "#FFFFFF")
        #expect(theme.colors.surfaceMuted.hex == "#F2EEE7")
        #expect(theme.colors.textPrimary.hex == "#15120F")
        #expect(theme.colors.accent.hex == "#A9F236")
        #expect(theme.metrics.cardCornerRadius == 28)
        #expect(theme.metrics.controlCornerRadius == 16)
        #expect(theme.effects.isPopArt == false)
    }

    @Test func normalThemeAdaptsSurfacesForDarkMode() {
        let theme = BabloTheme.normal.resolved(for: .dark)

        #expect(theme.colors.appBackground.hex == "#181411")
        #expect(theme.colors.surface.hex == "#241F1A")
        #expect(theme.colors.textPrimary.hex == "#F8F5EF")
        #expect(theme.colors.textSecondary.hex == "#CFC6B9")
        #expect(theme.colors.accent.hex == "#A9F236")
        #expect(theme.colors.line.hex == "#3A332B")
    }

    @Test func popThemeUsesComicPanelTokensInLightMode() {
        let theme = BabloTheme.pop.resolved(for: .light)

        #expect(theme.colors.appBackground.hex == "#FFF09A")
        #expect(theme.colors.surface.hex == "#FFFFFF")
        #expect(theme.colors.textPrimary.hex == "#0C0A08")
        #expect(theme.colors.accent.hex == "#A9F236")
        #expect(theme.colors.danger.hex == "#FF5F6D")
        #expect(theme.metrics.cardCornerRadius == 0)
        #expect(theme.metrics.controlCornerRadius == 4)
        #expect(theme.metrics.borderWidth == 2.5)
        #expect(theme.effects.isPopArt == true)
        #expect(theme.effects.halftoneDotOpacity == 0.18)
    }

    @Test func popThemeKeepsComicContrastInDarkMode() {
        let theme = BabloTheme.pop.resolved(for: .dark)

        #expect(theme.colors.appBackground.hex == "#2B1A06")
        #expect(theme.colors.surface.hex == "#3A260D")
        #expect(theme.colors.textPrimary.hex == "#FFF7D6")
        #expect(theme.colors.line.hex == "#FFF7D6")
        #expect(theme.metrics.cardCornerRadius == 0)
        #expect(theme.effects.isPopArt == true)
    }
}
