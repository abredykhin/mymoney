//
//  AccountEntity+Extensions.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/16/25.
//

import Foundation
import CoreData

extension AccountEntity {
    func update(with account: BankAccount) {
        self.id = Int64(account.id)
        self.name = account.name
        self.currentBalance = account.current_balance
        self.isoCurrencyCode = account.iso_currency_code
        self.type = account._type
        self.updatedAt = account.updated_at
        self.mask = account.mask
        self.officialName = account.official_name
        // Update hidden status if present
        if let hidden = account.hidden {
            self.hidden = hidden
        }
    }
}