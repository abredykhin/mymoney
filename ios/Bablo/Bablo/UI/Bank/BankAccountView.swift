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
        VStack(alignment: .leading, spacing: 16) {
                // Account Name
            Text(account.name)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
            Text(account._type.capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
                // Account Balance
            HStack {
                Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(getAccountColor(account))
                Spacer()
            }
            
                // Account Type (Optional: To add some visual interest)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
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
