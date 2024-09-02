//
//  ColorSet.swift
//  mymoney
//
//  Created by Anton Bredykhin on 4/25/24.
//

import SwiftUI

import SwiftUI

public let availableColorsSets: [ColorSetCouple] =
  [.init(light: DefaultLight(), dark: DefaultDark())]

public protocol ColorSet {
  var name: ColorSetName { get }
  var scheme: ColorScheme { get }
  var tintColor: Color { get set }
  var primaryBackgroundColor: Color { get set }
  var secondaryBackgroundColor: Color { get set }
  var labelColor: Color { get set }
}

public enum ColorScheme: String {
  case dark, light
}

public enum ColorSetName: String {
  case defaultDark = "Default - Dark"
  case defaultLight = "Default - Light"
}

public struct ColorSetCouple: Identifiable {
  public var id: String {
    dark.name.rawValue + light.name.rawValue
  }

  public let light: ColorSet
  public let dark: ColorSet
}

public struct DefaultDark: ColorSet {
  public var name: ColorSetName = .defaultDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(red: 187 / 255, green: 59 / 255, blue: 226 / 255)
  public var primaryBackgroundColor: Color = .init(red: 16 / 255, green: 21 / 255, blue: 35 / 255)
  public var secondaryBackgroundColor: Color = .init(red: 30 / 255, green: 35 / 255, blue: 62 / 255)
  public var labelColor: Color = .white

  public init() {}
}

public struct DefaultLight: ColorSet {
  public var name: ColorSetName = .defaultLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(red: 187 / 255, green: 59 / 255, blue: 226 / 255)
  public var primaryBackgroundColor: Color = .white
  public var secondaryBackgroundColor: Color = .init(hex: 0xF0F1F2)
  public var labelColor: Color = .black

  public init() {}
}
