//
//  ColorType.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/10/24.
//

enum ColorType: String, CaseIterable {
        /// Branding colors
    case accentColor
    case secondaryColor
            
    var name: String {
        self.rawValue
    }
}
