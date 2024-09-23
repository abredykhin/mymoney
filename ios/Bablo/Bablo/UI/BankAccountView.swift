    //
    //  AccountView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 9/2/24.
    //

import SwiftUI

struct BankAccountView : View {
    @State var account: BankAccount
    
    var body: some View {
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
        
    }
}

struct BankAccountView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        BankAccountView(account: account)
    }
}
