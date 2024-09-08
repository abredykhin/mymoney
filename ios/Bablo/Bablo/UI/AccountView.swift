//
//  AccountView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import SwiftUI

struct AccountView : View {
    @State var account: BankAccount
    
    var body: some View {
//        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text(account.name)
                    .font(.title)
                    .padding(.trailing, 4)
                Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                    .font(.title)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(10)
            .cardBackground()
//        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, item_id: 1, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        AccountView(account: account)
    }
}
