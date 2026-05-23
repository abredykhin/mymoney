import Foundation

#if DEBUG
extension AccountsService {
    static var onboardingPreviewEmpty: AccountsService {
        let service = AccountsService()
        service.banksWithAccounts = []
        return service
    }

    static var onboardingPreviewLinkedBank: AccountsService {
        let service = AccountsService()
        service.banksWithAccounts = Bank.onboardingPreviewBanks
        return service
    }
}

extension Bank {
    static let onboardingPreviewBanks: [Bank] = [
        Bank(
            id: 101,
            bank_name: "Bablo Credit Union",
            logo: nil,
            primary_color: "#111111",
            url: "https://example.com",
            accounts: [
                BankAccount(
                    id: 1,
                    item_id: 10,
                    name: "Everyday Checking",
                    mask: "2048",
                    official_name: "Everyday Checking",
                    current_balance: 2840.27,
                    available_balance: 2790.27,
                    _type: "depository",
                    subtype: "checking",
                    hidden: false,
                    iso_currency_code: "USD",
                    updated_at: Date()
                ),
                BankAccount(
                    id: 2,
                    item_id: 10,
                    name: "Rainy Day Savings",
                    mask: "7781",
                    official_name: "High Yield Savings",
                    current_balance: 9750.00,
                    available_balance: 9750.00,
                    _type: "depository",
                    subtype: "savings",
                    hidden: false,
                    iso_currency_code: "USD",
                    updated_at: Date()
                ),
                BankAccount(
                    id: 3,
                    item_id: 10,
                    name: "Rewards Card",
                    mask: "4219",
                    official_name: "Rewards Credit Card",
                    current_balance: 684.12,
                    available_balance: nil,
                    _type: "credit",
                    subtype: "credit card",
                    hidden: false,
                    iso_currency_code: "USD",
                    updated_at: Date()
                )
            ]
        )
    ]
}

extension Dictionary where Key == FixedExpenseCategory, Value == Int {
    static var onboardingPreviewPrefilled: [FixedExpenseCategory: Int] {
        [
            .rent: 2200,
            .phone: 85,
            .utilities: 160,
            .streaming: 42
        ]
    }
}

extension Set where Element == FlexibleSpendingCategory {
    static var onboardingPreviewSelected: Set<FlexibleSpendingCategory> {
        [.eatsOut, .coffeeRuns, .shopping, .gettingAround]
    }
}
#endif
