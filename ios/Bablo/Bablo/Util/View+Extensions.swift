//
//  View+Extensions.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI

extension View {
    func Print(_ vars: Any...) -> some View {
        for v in vars { debugPrint(v) }
        return EmptyView()
    }
}

struct GlobalConditionalItalic: ViewModifier {
    let isEnabled: Bool
    func body(content: Content) -> some View {
        if isEnabled {
            content.italic()
        } else {
            content
        }
    }
}

extension View {
    func conditionalItalic(_ isEnabled: Bool) -> some View {
        modifier(GlobalConditionalItalic(isEnabled: isEnabled))
    }
}


