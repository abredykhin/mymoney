//
//  Bank.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

import Foundation

struct Bank {
    let id: Int
    let bank_name: String
    let accounts: [BankAccount]
}

struct MockBanks {
    static let bank = Bank(id: 0, bank_name: "A Bank", accounts: [
        MockAccounts.account1,
        MockAccounts.account2
    ])
}
