//
//  MockBankAccountsManager.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/29/24.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

typealias BankAccount = Components.Schemas.Account
extension BankAccount : Identifiable {
    
}

class MockBankAccountsManager: BankAccountsManager {
    
    override init() {
        super.init()
        self.accounts = [
            BankAccount(id: 0, item_id: 1, name: "1st Account", current_balance: 100.0, iso_currency_code: "USD", _type: "checking", updated_at: Date(timeIntervalSinceNow: .zero)),
            BankAccount(id: 1, item_id: 2, name: "2nd Account", current_balance: 800.0, iso_currency_code: "USD", _type: "debit", updated_at: Date(timeIntervalSinceNow: .zero)),
            BankAccount(id: 0, item_id: 3, name: "3rd Account", current_balance: 500000.0, iso_currency_code: "USD", _type: "IRA", updated_at: Date(timeIntervalSinceNow: .zero))
        ]
    }
    
    override func refreshAccounts() async throws {
        // DO NOTHING
    }
}
