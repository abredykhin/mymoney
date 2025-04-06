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
        HStack {
            VStack(alignment: .leading) {
                HStack {
                        // Account Name
                    Text(account.name)
                        .font(.body.weight(.semibold).monospaced())
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                        .font(.body.weight(.semibold).monospaced())
                        .foregroundColor(getAccountColor(account))
                }
                Text(account._type.capitalized)
                    .font(.footnote.monospaced())
                    .foregroundColor(.secondary)
            }
            .padding(4)
        }
    }
    
    private func getGradient() -> LinearGradient {
        if (account._type == "depository") {
            return LinearGradient(gradient: Gradient(colors: [.teal, .green]),
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing)
            
        } else {
            return LinearGradient(gradient: Gradient(colors: [.teal, .green]),
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing)
        }
    }
    
    private func getAccountColor(_ account: BankAccount) -> Color {
        switch account._type {
        case "depository", "investment":
            return account.current_balance > 0 ? .green : .red
        default:
            return .red
        }
    }
}

struct BankAccountView_Previews: PreviewProvider {
    static let account = BankAccount(id: 0, name: "Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static var previews: some View {
        BankAccountView(account: account)
    }
}
