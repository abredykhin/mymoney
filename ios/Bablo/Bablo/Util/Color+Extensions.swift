//
//  Color+Extensions.swift
//  Bablo
//
//  Created by Anton Bredykhin on 4/5/25.
//

import SwiftUI

extension Color {
    init?(hex: String?) {
        guard var hexString = hex else { return nil }
        
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        guard hexString.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
            return nil
        }
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
