//
//  Theme.swift
//  mymoney
//
//  Created by Anton Bredykhin on 4/25/24.
//

import SwiftUI
import Combine
import SwiftUI

@Observable public class Theme {
  class ThemeStorage {
    enum ThemeKey: String {
      case colorScheme, tint, label, primaryBackground, secondaryBackground
      case selectedSet, selectedScheme
      case followSystemColorScheme
      case lineSpacing
      case statusActionSecondary
    }

    @AppStorage("is_previously_set") public var isThemePreviouslySet: Bool = false
    @AppStorage(ThemeKey.selectedScheme.rawValue) public var selectedScheme: ColorScheme = .dark
    @AppStorage(ThemeKey.tint.rawValue) public var tintColor: Color = .black
    @AppStorage(ThemeKey.primaryBackground.rawValue) public var primaryBackgroundColor: Color = .white
    @AppStorage(ThemeKey.secondaryBackground.rawValue) public var secondaryBackgroundColor: Color = .gray
    @AppStorage(ThemeKey.label.rawValue) public var labelColor: Color = .black
    @AppStorage(ThemeKey.selectedSet.rawValue) var storedSet: ColorSetName = .defaultLight
    @AppStorage(ThemeKey.followSystemColorScheme.rawValue) public var followSystemColorScheme: Bool = true
    @AppStorage(ThemeKey.lineSpacing.rawValue) public var lineSpacing: Double = 1.2
    @AppStorage("font_size_scale") public var fontSizeScale: Double = 1
    @AppStorage("chosen_font") public var chosenFontData: Data?

    init() {}
  }

  public enum FontState: Int, CaseIterable {
    case system
    case SFRounded
    case custom

    public var title: LocalizedStringKey {
      switch self {
      case .system:
        "settings.display.font.system"
      case .SFRounded:
        "SF Rounded"
      case .custom:
        "settings.display.font.custom"
      }
    }
  }

  private var _cachedChoosenFont: UIFont?
  public var chosenFont: UIFont? {
    get {
      if let _cachedChoosenFont {
        return _cachedChoosenFont
      }
      guard let chosenFontData,
            let font = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIFont.self, from: chosenFontData) else { return nil }

      _cachedChoosenFont = font
      return font
    }
    set {
      if let font = newValue,
         let data = try? NSKeyedArchiver.archivedData(withRootObject: font, requiringSecureCoding: false)
      {
        chosenFontData = data
      } else {
        chosenFontData = nil
      }
      _cachedChoosenFont = nil
    }
  }

  let themeStorage = ThemeStorage()

  public var isThemePreviouslySet: Bool {
    didSet {
      themeStorage.isThemePreviouslySet = isThemePreviouslySet
    }
  }

  public var selectedScheme: ColorScheme {
    didSet {
      themeStorage.selectedScheme = selectedScheme
    }
  }

  public var tintColor: Color {
    didSet {
      themeStorage.tintColor = tintColor
      computeContrastingTintColor()
    }
  }

  public var primaryBackgroundColor: Color {
    didSet {
      themeStorage.primaryBackgroundColor = primaryBackgroundColor
      computeContrastingTintColor()
    }
  }

  public var secondaryBackgroundColor: Color {
    didSet {
      themeStorage.secondaryBackgroundColor = secondaryBackgroundColor
    }
  }

  public var labelColor: Color {
    didSet {
      themeStorage.labelColor = labelColor
      computeContrastingTintColor()
    }
  }

  public private(set) var contrastingTintColor: Color

  // set contrastingTintColor to either labelColor or primaryBackgroundColor, whichever contrasts
  // better against the tintColor
  private func computeContrastingTintColor() {
    func luminance(_ color: Color.Resolved) -> Float {
      return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
    }

    let resolvedTintColor = tintColor.resolve(in: .init())
    let resolvedLabelColor = labelColor.resolve(in: .init())
    let resolvedPrimaryBackgroundColor = primaryBackgroundColor.resolve(in: .init())

    let tintLuminance = luminance(resolvedTintColor)
    let labelLuminance = luminance(resolvedLabelColor)
    let primaryBackgroundLuminance = luminance(resolvedPrimaryBackgroundColor)

    if abs(tintLuminance - labelLuminance) > abs(tintLuminance - primaryBackgroundLuminance) {
      contrastingTintColor = labelColor
    } else {
      contrastingTintColor = primaryBackgroundColor
    }
  }

  private var storedSet: ColorSetName {
    didSet {
      themeStorage.storedSet = storedSet
    }
  }

  public var followSystemColorScheme: Bool {
    didSet {
      themeStorage.followSystemColorScheme = followSystemColorScheme
    }
  }

  public var lineSpacing: Double {
    didSet {
      themeStorage.lineSpacing = lineSpacing
    }
  }

  public var fontSizeScale: Double {
    didSet {
      themeStorage.fontSizeScale = fontSizeScale
    }
  }

  public private(set) var chosenFontData: Data? {
    didSet {
      themeStorage.chosenFontData = chosenFontData
    }
  }

  public var selectedSet: ColorSetName = .defaultLight

  public static let shared = Theme()

  public func restoreDefault() {
    applySet(set: themeStorage.selectedScheme == .dark ? .defaultDark : .defaultLight)
    isThemePreviouslySet = true
    storedSet = selectedSet
    followSystemColorScheme = true
    lineSpacing = 1.2
    fontSizeScale = 1
    chosenFontData = nil
  }

  private init() {
    isThemePreviouslySet = themeStorage.isThemePreviouslySet
    selectedScheme = themeStorage.selectedScheme
    tintColor = themeStorage.tintColor
    primaryBackgroundColor = themeStorage.primaryBackgroundColor
    secondaryBackgroundColor = themeStorage.secondaryBackgroundColor
    labelColor = themeStorage.labelColor
    contrastingTintColor = .red // real work done in computeContrastingTintColor()
    storedSet = themeStorage.storedSet
    followSystemColorScheme = themeStorage.followSystemColorScheme
    lineSpacing = themeStorage.lineSpacing
    fontSizeScale = themeStorage.fontSizeScale
    chosenFontData = themeStorage.chosenFontData
    selectedSet = storedSet

    computeContrastingTintColor()
  }

  public static var allColorSet: [ColorSet] {
    [
      DefaultDark(),
      DefaultLight(),
    ]
  }

  public func applySet(set: ColorSetName) {
    selectedSet = set
    setColor(withName: set)
  }

  public func setColor(withName name: ColorSetName) {
    let colorSet = Theme.allColorSet.filter { $0.name == name }.first ?? DefaultLight()
    selectedScheme = colorSet.scheme
    tintColor = colorSet.tintColor
    primaryBackgroundColor = colorSet.primaryBackgroundColor
    secondaryBackgroundColor = colorSet.secondaryBackgroundColor
    labelColor = colorSet.labelColor
    storedSet = name
  }
}
