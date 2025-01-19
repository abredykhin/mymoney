    //
    //  LargeButton.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 12/14/24.
    //

import SwiftUI

struct LargeButton : View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity) // Makes the button fill the width
                .font(.headline)
                .foregroundColor(.white)
                .background(Color.blue) // Button background color
                .cornerRadius(10)
        }.padding(.horizontal)
    }
}

#Preview {
    LargeButton(title: "Continue", action: {})
}
