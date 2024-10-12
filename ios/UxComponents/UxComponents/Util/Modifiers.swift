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
            .background(Color(.white))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 4)
            .padding(10)
    }
}

