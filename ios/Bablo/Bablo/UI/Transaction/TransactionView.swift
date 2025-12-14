//
//  TransactionView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/23/24.
//

import SwiftUI

struct TransactionView: View {
    @State var transaction: Transaction
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Image(systemName: transaction.getDetailedCategoryIconName())
                    .font(.callout)
                    .foregroundStyle(getCategoryColor())
                    .frame(width: 24)
                
                Text(transaction.merchant_name ?? transaction.name)
                    .font(.callout)
                    .monospaced()
                    .lineLimit(1)
                    .bold()
                
                Spacer()
                Text(-transaction.amount, format: .currency(code: transaction.iso_currency_code ?? "USD"))
                    .font(.callout)
                    .monospaced()
                    .foregroundStyle(getColor())
            }
            HStack(alignment: .top) {
                Text(formatDate(transaction.authorized_date ?? transaction.date))
                    .font(.footnote)
                    .monospaced()
                
                Spacer()
                if (transaction.pending) {
                    Text("Pending")
                        .font(.footnote)
                        .monospaced()
                        .italic()
                }
            }
        }.padding(1)
    }
    
    func getColor() -> Color {
        return transaction.amount > 0 ? .red : .teal
    }
    
    func getCategoryColor() -> Color {
        guard let category = transaction.personal_finance_category else {
            return .secondary
        }
        
        let primaryCategory = category.split(separator: "_").first?.uppercased() ?? ""
        
        switch primaryCategory {
        case "INCOME":
            return .green
        case "TRANSFER_IN":
            return .blue
        case "TRANSFER_OUT":
            return .orange
        case "LOAN_PAYMENTS":
            return .purple
        case "BANK_FEES":
            return .red
        case "FOOD_AND_DRINK":
            return .pink
        case "ENTERTAINMENT":
            return .indigo
        case "TRAVEL":
            return .cyan
        default:
            return .secondary
        }
    }
}

struct TransactionView_Previews: PreviewProvider {
    // Sample transactions with different categories
    static let foodTransaction = Transaction(
        id: 1,
        account_id: 0,
        amount: 12.50,
        date: "2024-12-01",
        authorized_date: "2024-12-01",
        name: "McDonalds",
        merchant_name: "McDonalds",
        pending: false,
        category: ["Food and Drink", "Restaurants"],
        transaction_id: "1",
        pending_transaction_transaction_id: nil,
        iso_currency_code: "USD",
        payment_channel: "online",
        user_id: nil,
        logo_url: nil,
        website: nil,
        personal_finance_category: "FOOD_AND_DRINK",
        personal_finance_subcategory: "FOOD_AND_DRINK_FAST_FOOD",
        created_at: nil,
        updated_at: nil
    )

    static let travelTransaction = Transaction(
        id: 2,
        account_id: 0,
        amount: 350.75,
        date: "2024-12-05",
        authorized_date: "2024-12-05",
        name: "Delta Airlines",
        merchant_name: "Delta Airlines",
        pending: true,
        category: ["Travel"],
        transaction_id: "2",
        pending_transaction_transaction_id: nil,
        iso_currency_code: "USD",
        payment_channel: "online",
        user_id: nil,
        logo_url: nil,
        website: nil,
        personal_finance_category: "TRAVEL",
        personal_finance_subcategory: nil,
        created_at: nil,
        updated_at: nil
    )

    static let incomeTransaction = Transaction(
        id: 3,
        account_id: 0,
        amount: -2500.00,  // Negative to show as income
        date: "2024-12-15",
        authorized_date: "2024-12-15",
        name: "ACME Corp Payroll",
        merchant_name: "ACME Corp",
        pending: false,
        category: ["Income", "Payroll"],
        transaction_id: "3",
        pending_transaction_transaction_id: nil,
        iso_currency_code: "USD",
        payment_channel: "other",
        user_id: nil,
        logo_url: nil,
        website: nil,
        personal_finance_category: "INCOME",
        personal_finance_subcategory: nil,
        created_at: nil,
        updated_at: nil
    )
    
    static var previews: some View {
        VStack(spacing: 10) {
            TransactionView(transaction: foodTransaction)
                .border(Color.gray.opacity(0.2))
            
            TransactionView(transaction: travelTransaction)
                .border(Color.gray.opacity(0.2))
            
            TransactionView(transaction: incomeTransaction)
                .border(Color.gray.opacity(0.2))
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Transaction Categories Preview")
    }
}
