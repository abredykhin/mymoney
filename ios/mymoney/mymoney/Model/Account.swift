//
//  Account.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation

struct Account {
    let id: String
    let itemId: String // associated Plaid Item
    let name: String
    let mask: String
    let officialName: String
    let currentBalance: Decimal
    let availableBalance: Decimal
    let currencyCode: String
    let type: String
    let updatedAt: Date
}
