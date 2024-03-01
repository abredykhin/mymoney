//
//  MockBankAccountsManager.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/29/24.
//

import Foundation

class MockBankAccountsManager: BankAccountsManager {
    
    override init() {
        super.init()
        self.accounts = [
            BankAccount(id: 0, item_id: 0, name: "1st Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: Date(timeIntervalSinceNow: .zero)),
            BankAccount(id: 1, item_id: 0, name: "2nd Account", current_balance: 800.0, iso_currency_code: "USD", _type: "debit", updated_at: Date(timeIntervalSinceNow: .zero)),
            BankAccount(id: 0, item_id: 0, name: "3rd Account", current_balance: 500000.0, iso_currency_code: "USD", _type: "IRA", updated_at: Date(timeIntervalSinceNow: .zero))
        ]
    }
}
