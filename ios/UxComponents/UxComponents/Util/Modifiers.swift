//
//  Modifiers.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import SwiftUI

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
//            .background(Color(.green).opacity(0.1))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 8)
            .padding(10)
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
