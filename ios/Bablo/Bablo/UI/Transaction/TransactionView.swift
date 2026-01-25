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
                    .font(Typography.body)
                    .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : getCategoryColor())
                    .frame(width: 24)

                Text(transaction.merchant_name ?? transaction.name)
                    .font(Typography.body)
                    .lineLimit(1)
                    .bold()
                    .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : ColorPalette.textPrimary)

                Spacer()
                Text(-transaction.amount, format: .currency(code: transaction.iso_currency_code ?? "USD"))
                    .font(Typography.transactionAmount)
                    .foregroundStyle(getColor())
            }
            HStack(alignment: .top) {
                Text(formatDate(transaction.authorized_date ?? transaction.date))
                    .font(Typography.transactionDetail)
                    .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : ColorPalette.textSecondary)

                Spacer()
                if (transaction.pending) {
                    Text("Pending")
                        .font(Typography.transactionDetail)
                        .italic()
                        .foregroundStyle(transaction.isTransfer ? ColorPalette.textSecondary : ColorPalette.textSecondary)
                }
            }
        }.padding(.vertical, Spacing.sm)
         .padding(.horizontal, Spacing.xxs)
    }

    func getColor() -> Color {
        // Transfers are displayed in gray
        if transaction.isTransfer {
            return ColorPalette.textSecondary
        }
        return transaction.amount > 0 ? ColorPalette.error : ColorPalette.success
    }
    
    func getCategoryColor() -> Color {
        guard let category = transaction.personal_finance_category else {
            return ColorPalette.categoryDefault
        }
        
        // Handle "TRANSFER_IN" or "TRANSFER_OUT" which might be the category string themselves
        // or starting with them. The original code split by "_" and took first.
        // But "TRANSFER_IN" split by "_" first is "TRANSFER".
        // Let's look at original logic:
        // let primaryCategory = category.split(separator: "_").first?.uppercased() ?? ""
        // if category is "FOOD_AND_DRINK", primary is "FOOD".
        // if "TRANSFER_IN", primary is "TRANSFER".
        // wait, the original switch case had "TRANSFER_IN" and "TRANSFER_OUT".
        // If split by "_", "TRANSFER_IN" becomes ["TRANSFER", "IN"]. first is "TRANSFER".
        // So case "TRANSFER_IN" would NEVER match in original code if it was checking just the first part!
        // Let's re-read the original code carefully.
        
        /*
        let primaryCategory = category.split(separator: "_").first?.uppercased() ?? ""
        switch primaryCategory {
        case "INCOME": ...
        case "TRANSFER_IN": ... 
        */
        
        // If category is "TRANSFER_IN", primaryCategory is "TRANSFER".
        // So "TRANSFER_IN" case is unreachable in original code unless the string is just "TRANSFER_IN" and split doesn't split it? No, split("_") splits.
        // Ah, maybe the category string format is different.
        // Assuming the Migration Plan logic is the desired one, which uses the full string logic or at least mapping.
        // The migration plan suggested:
        /*
        switch category {
            case "INCOME": return ColorPalette.categoryIncome
            ...
        }
        */
        // It removed the `split` logic in the plan's suggested code.
        // I should try to replicate the INTENT or improve it.
        // If I follow the plan strictly (Step 2.2), it says:
        /*
        // NEW
        private func getCategoryColor(for category: String?) -> Color {
            guard let category = category else { return ColorPalette.categoryDefault }
        
            switch category {
            case "INCOME": return ColorPalette.categoryIncome
            ...
        */
        // But here `getCategoryColor` is a method of `TransactionView` taking no args (uses `transaction.personal_finance_category`).
        // And the plan's snippet shows `case "FOOD_AND_DRINK": return ColorPalette.categoryFood`.
        // So the plan assumes we are switching on the FULL category string (or at least the `personal_finance_category` enum value from Plaid).
        // Plaid categories are like "FOOD_AND_DRINK", "TRAVEL", "TRANSFER_IN", "TRANSFER_OUT".
        // So the `split` in original code might have been WRONG for "TRANSFER_IN" but RIGHT for "FOOD_AND_DRINK" if the intention was to group.
        // But "FOOD_AND_DRINK" is a top level category.
        // "FOOD_AND_DRINK_FAST_FOOD" is sub.
        // If Plaid sends "FOOD_AND_DRINK", split("_") first is "FOOD".
        // But the case was "FOOD_AND_DRINK". So "FOOD" != "FOOD_AND_DRINK".
        // So original code `split` logic vs case logic seems mismatched for "FOOD_AND_DRINK" too.
        // UNLESS the prompt/doc implies Plaid returns something else?
        // Actually, Plaid `personal_finance_category.primary` is usually human readable like "Food and Drink".
        // But here the code uses `personal_finance_category` which seems to be the SNAKE_CASE one.
        // If the original code was BUGGY, I should fix it.
        // If `category` is "FOOD_AND_DRINK", `primaryCategory` is "FOOD".
        // `switch "FOOD"` -> case "FOOD_AND_DRINK" is false.
        // So all these returned `.secondary` (teal default in original was in default case).
        // Wait, original default was `.teal`.
        // So maybe all these specific colors were BROKEN in the original code?
        // If so, implementing it correctly now is a huge win.
        // I will implement the check based on `category` (the full string) or `startsWith`.
        
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
