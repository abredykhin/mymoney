//
//  Account.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import Foundation

struct BankAccount {
    let id: Int
    let name: String
    let current_balance: Double
    let iso_currency_code: String
    let _type: String
    let updated_at: Date
}

struct MockAccounts {
    static let account1 = BankAccount(id: 0, name: "Chase", current_balance: 23110.23, iso_currency_code: "USD", _type: "checking", updated_at: .now)
    static let account2 = BankAccount(id: 1, name: "Citi", current_balance: 1292.11, iso_currency_code: "USD", _type: "credit", updated_at: .now)
}
