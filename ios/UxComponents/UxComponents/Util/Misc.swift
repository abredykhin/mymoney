//
//  Misc.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import SwiftUI

extension View {
    func Print(_ vars: Any...) -> some View {
        for v in vars { debugPrint(v) }
        return EmptyView()
    }
}
