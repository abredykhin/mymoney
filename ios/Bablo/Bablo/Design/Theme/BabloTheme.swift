import SwiftUI

enum BabloTheme: String, CaseIterable, Identifiable {
    case normal
    case pop

    var id: String { rawValue }

    func resolved(for colorScheme: ColorScheme) -> BabloResolvedTheme {
        switch (self, colorScheme) {
        case (.normal, .light):
            return .normalLight
        case (.normal, .dark):
            return .normalDark
        case (.pop, .light):
            return .popLight
        case (.pop, .dark):
            return .popDark
        @unknown default:
            return .normalLight
        }
    }
}

struct BabloResolvedTheme {
    let variant: BabloTheme
    let colorScheme: ColorScheme
    let colors: BabloThemeColors
    let typography: BabloTypography
    let metrics: BabloThemeMetrics
    let effects: BabloThemeEffects
}

struct BabloColorToken: Equatable {
    let hex: String

    var color: Color {
        Color(hex: hex) ?? .clear
    }
}

struct BabloThemeColors: Equatable {
    let pageBackground: BabloColorToken
    let appBackground: BabloColorToken
    let surface: BabloColorToken
    let surfaceMuted: BabloColorToken
    let textPrimary: BabloColorToken
    let textSecondary: BabloColorToken
    let textTertiary: BabloColorToken
    let line: BabloColorToken
    let lineStrong: BabloColorToken
    let accent: BabloColorToken
    let accentPressed: BabloColorToken
    let accentDeep: BabloColorToken
    let accentInk: BabloColorToken
    let success: BabloColorToken
    let warning: BabloColorToken
    let danger: BabloColorToken
    let info: BabloColorToken
    let avatarPink: BabloColorToken
}

struct BabloTypography: Equatable {
    let bodyDesign: Font.Design
    let displayDesign: Font.Design
    let displayTracking: CGFloat
    let labelTracking: CGFloat
    let isUppercaseDisplay: Bool

    func display(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: displayDesign)
    }

    func title(size: CGFloat = 32, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: bodyDesign)
    }

    func body(size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: bodyDesign)
    }

    func mono(size: CGFloat = 16, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct BabloThemeMetrics: Equatable {
    let screenPadding: CGFloat
    let cardPadding: CGFloat
    let cardCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let buttonCornerRadius: CGFloat
    let iconCornerRadius: CGFloat
    let borderWidth: CGFloat
    let strongBorderWidth: CGFloat
    let buttonHeight: CGFloat
    let compactButtonHeight: CGFloat
}

struct BabloThemeEffects: Equatable {
    let isPopArt: Bool
    let halftoneDotOpacity: Double
    let shadowColorHex: String
    let shadowRadius: CGFloat
    let shadowX: CGFloat
    let shadowY: CGFloat
    let pressedScale: CGFloat
    let pressedOffset: CGSize

    var shadowColor: Color {
        Color(hex: shadowColorHex) ?? .black
    }
}

private extension BabloResolvedTheme {
    static let normalLight = BabloResolvedTheme(
        variant: .normal,
        colorScheme: .light,
        colors: BabloThemeColors(
            pageBackground: "#E8E3D7",
            appBackground: "#F8F5EF",
            surface: "#FFFFFF",
            surfaceMuted: "#F2EEE7",
            textPrimary: "#15120F",
            textSecondary: "#5B554E",
            textTertiary: "#918A82",
            line: "#E4DED4",
            lineStrong: "#D6CEC1",
            accent: "#A9F236",
            accentPressed: "#8DE000",
            accentDeep: "#24410F",
            accentInk: "#122100",
            success: "#078A2E",
            warning: "#C88A14",
            danger: "#FF5F6D",
            info: "#1099E6",
            avatarPink: "#F76C9E"
        ),
        typography: .normal,
        metrics: .normal,
        effects: .normal
    )

    static let normalDark = BabloResolvedTheme(
        variant: .normal,
        colorScheme: .dark,
        colors: BabloThemeColors(
            pageBackground: "#0F0C0A",
            appBackground: "#181411",
            surface: "#241F1A",
            surfaceMuted: "#2D261F",
            textPrimary: "#F8F5EF",
            textSecondary: "#CFC6B9",
            textTertiary: "#918A82",
            line: "#3A332B",
            lineStrong: "#4B4238",
            accent: "#A9F236",
            accentPressed: "#8DE000",
            accentDeep: "#D5FF88",
            accentInk: "#122100",
            success: "#55D779",
            warning: "#F3B84F",
            danger: "#FF7A84",
            info: "#68C5FF",
            avatarPink: "#FF7BAA"
        ),
        typography: .normal,
        metrics: .normal,
        effects: .normalDark
    )

    static let popLight = BabloResolvedTheme(
        variant: .pop,
        colorScheme: .light,
        colors: BabloThemeColors(
            pageBackground: "#E8E3D7",
            appBackground: "#FFF09A",
            surface: "#FFFFFF",
            surfaceMuted: "#FFF7C9",
            textPrimary: "#0C0A08",
            textSecondary: "#2A2520",
            textTertiary: "#5A554F",
            line: "#0C0A08",
            lineStrong: "#0C0A08",
            accent: "#A9F236",
            accentPressed: "#8DE000",
            accentDeep: "#0C0A08",
            accentInk: "#0C0A08",
            success: "#078A2E",
            warning: "#FFCF33",
            danger: "#FF5F6D",
            info: "#149FE3",
            avatarPink: "#F76C9E"
        ),
        typography: .pop,
        metrics: .pop,
        effects: .pop
    )

    static let popDark = BabloResolvedTheme(
        variant: .pop,
        colorScheme: .dark,
        colors: BabloThemeColors(
            pageBackground: "#120B03",
            appBackground: "#2B1A06",
            surface: "#3A260D",
            surfaceMuted: "#2D1C08",
            textPrimary: "#FFF7D6",
            textSecondary: "#D9C99E",
            textTertiary: "#A99668",
            line: "#FFF7D6",
            lineStrong: "#FFF7D6",
            accent: "#A9F236",
            accentPressed: "#8DE000",
            accentDeep: "#FFF7D6",
            accentInk: "#0C0A08",
            success: "#8DE000",
            warning: "#FFCF33",
            danger: "#FF5F6D",
            info: "#61D1FF",
            avatarPink: "#F76C9E"
        ),
        typography: .pop,
        metrics: .pop,
        effects: .popDark
    )
}

private extension BabloThemeColors {
    init(
        pageBackground: String,
        appBackground: String,
        surface: String,
        surfaceMuted: String,
        textPrimary: String,
        textSecondary: String,
        textTertiary: String,
        line: String,
        lineStrong: String,
        accent: String,
        accentPressed: String,
        accentDeep: String,
        accentInk: String,
        success: String,
        warning: String,
        danger: String,
        info: String,
        avatarPink: String
    ) {
        self.pageBackground = BabloColorToken(hex: pageBackground)
        self.appBackground = BabloColorToken(hex: appBackground)
        self.surface = BabloColorToken(hex: surface)
        self.surfaceMuted = BabloColorToken(hex: surfaceMuted)
        self.textPrimary = BabloColorToken(hex: textPrimary)
        self.textSecondary = BabloColorToken(hex: textSecondary)
        self.textTertiary = BabloColorToken(hex: textTertiary)
        self.line = BabloColorToken(hex: line)
        self.lineStrong = BabloColorToken(hex: lineStrong)
        self.accent = BabloColorToken(hex: accent)
        self.accentPressed = BabloColorToken(hex: accentPressed)
        self.accentDeep = BabloColorToken(hex: accentDeep)
        self.accentInk = BabloColorToken(hex: accentInk)
        self.success = BabloColorToken(hex: success)
        self.warning = BabloColorToken(hex: warning)
        self.danger = BabloColorToken(hex: danger)
        self.info = BabloColorToken(hex: info)
        self.avatarPink = BabloColorToken(hex: avatarPink)
    }
}

private extension BabloTypography {
    static let normal = BabloTypography(
        bodyDesign: .default,
        displayDesign: .rounded,
        displayTracking: 0,
        labelTracking: 1.8,
        isUppercaseDisplay: false
    )

    static let pop = BabloTypography(
        bodyDesign: .rounded,
        displayDesign: .rounded,
        displayTracking: 1.2,
        labelTracking: 2.4,
        isUppercaseDisplay: true
    )
}

private extension BabloThemeMetrics {
    static let normal = BabloThemeMetrics(
        screenPadding: 16,
        cardPadding: 24,
        cardCornerRadius: 28,
        controlCornerRadius: 16,
        buttonCornerRadius: 16,
        iconCornerRadius: 14,
        borderWidth: 0.5,
        strongBorderWidth: 1,
        buttonHeight: 56,
        compactButtonHeight: 42
    )

    static let pop = BabloThemeMetrics(
        screenPadding: 16,
        cardPadding: 20,
        cardCornerRadius: 0,
        controlCornerRadius: 4,
        buttonCornerRadius: 4,
        iconCornerRadius: 4,
        borderWidth: 2.5,
        strongBorderWidth: 3,
        buttonHeight: 58,
        compactButtonHeight: 44
    )
}

private extension BabloThemeEffects {
    static let normal = BabloThemeEffects(
        isPopArt: false,
        halftoneDotOpacity: 0,
        shadowColorHex: "#000000",
        shadowRadius: 24,
        shadowX: 0,
        shadowY: 8,
        pressedScale: 0.985,
        pressedOffset: .zero
    )

    static let normalDark = BabloThemeEffects(
        isPopArt: false,
        halftoneDotOpacity: 0,
        shadowColorHex: "#000000",
        shadowRadius: 18,
        shadowX: 0,
        shadowY: 6,
        pressedScale: 0.985,
        pressedOffset: .zero
    )

    static let pop = BabloThemeEffects(
        isPopArt: true,
        halftoneDotOpacity: 0.18,
        shadowColorHex: "#0C0A08",
        shadowRadius: 0,
        shadowX: 4,
        shadowY: 4,
        pressedScale: 1,
        pressedOffset: CGSize(width: 2, height: 2)
    )

    static let popDark = BabloThemeEffects(
        isPopArt: true,
        halftoneDotOpacity: 0.18,
        shadowColorHex: "#FFF7D6",
        shadowRadius: 0,
        shadowX: 4,
        shadowY: 4,
        pressedScale: 1,
        pressedOffset: CGSize(width: 2, height: 2)
    )
}
