//
//  CurrencyTextField.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct CurrencyTextField: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        TextField(title, value: $value, format: .currency(code: "USD"))
            .font(Typography.body)
            .keyboardType(.decimalPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

