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
        HStack(alignment: .center) {
            Image(systemName: transaction.getDetailedCategoryIconName())
                .font(Typography.caption)
                .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : getCategoryColor())
                .frame(width: 20)

            Text(transaction.merchant_name ?? transaction.name)
                .font(Typography.captionBold)
                .italic(transaction.pending)
                .lineLimit(1)
                .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : ColorPalette.textPrimary)

            Spacer()

            Text(-transaction.amount, format: .currency(code: transaction.iso_currency_code ?? "USD"))
                .font(Typography.monoSmall)
                .italic(transaction.pending)
                .foregroundStyle(getColor())
        }
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.xxs)
    }

    func getColor() -> Color {
        // Transfers are displayed in gray
        if transaction.isTransfer {
            return ColorPalette.textSecondary
        }

        // Credit card payments are displayed in dark grey
        if let subcategory = transaction.personal_finance_subcategory?.uppercased(),
           subcategory == "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT" {
            return ColorPalette.textSecondary
        }

        // Income is green, spending is black
        return transaction.amount > 0 ? ColorPalette.textPrimary : ColorPalette.success
    }
    
    func getCategoryColor() -> Color {
        guard let category = transaction.personal_finance_category else {
            return ColorPalette.categoryDefault
        }
        
        let normalizedCategory = category.uppercased()
        
        if normalizedCategory == "INCOME" { return ColorPalette.categoryIncome }
        if normalizedCategory == "TRANSFER_IN" { return ColorPalette.categoryTransferIn }
        if normalizedCategory == "TRANSFER_OUT" { return ColorPalette.categoryTransferOut }
        if normalizedCategory == "LOAN_PAYMENTS" { return ColorPalette.categoryLoanPayments }
        if normalizedCategory == "BANK_FEES" { return ColorPalette.categoryBankFees }
        if normalizedCategory == "FOOD_AND_DRINK" { return ColorPalette.categoryFood }
        if normalizedCategory == "ENTERTAINMENT" { return ColorPalette.categoryEntertainment }
        if normalizedCategory == "TRAVEL" { return ColorPalette.categoryTravel }
        
        return ColorPalette.categoryDefault
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
