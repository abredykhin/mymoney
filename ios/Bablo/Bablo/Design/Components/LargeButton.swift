    //
    //  LargeButton.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 12/14/24.
    //

import SwiftUI

struct LargeButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .primaryButton(isLoading: isLoading, isDisabled: isDisabled)
        .screenPadding()
    }
}

#Preview {
    LargeButton(title: "Continue", action: {})
}
