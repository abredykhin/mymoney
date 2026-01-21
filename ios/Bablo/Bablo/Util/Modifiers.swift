//
//  Modifiers.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/7/24.
//

import SwiftUI

@available(*, deprecated, message: "Use .card() from the design system instead")
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
    static let account = BankAccount(
        id: 0,
        item_id: 1,
        name: "Account",
        mask: "1234",
        official_name: "Checking Account",
        current_balance: 100.0,
        available_balance: 95.0,
        _type: "checking",
        subtype: nil,
        hidden: false,
        iso_currency_code: "USD",
        updated_at: Date.now
    )
    static var previews: some View {
        BankAccountView(account: account)
            .cardBackground()
    }
}
