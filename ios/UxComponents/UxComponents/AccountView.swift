//
//  AccountView.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import SwiftUI

struct AccountView: View {
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
            
                // Account Balance
            HStack {
                Text(account.current_balance, format: .currency(code: account.iso_currency_code))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(account._type == "depository" && account.current_balance > 0 ? .green : .red)
                Spacer()
            }
            
                // Account Type (Optional: To add some visual interest)
            Text(account._type.capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
}

#Preview {
    AccountView(account: MockAccounts.account1)
}
