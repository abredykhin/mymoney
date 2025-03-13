//
//  Modifiers.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/7/24.
//

import SwiftUI

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.white))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 4)
            .padding(8)
    }
}

struct CardBackground_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        BankAccountView(account: account)
            .cardBackground()
    }
}
