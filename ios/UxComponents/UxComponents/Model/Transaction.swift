//
//  Transaction.swift
//  UxComponents
//
//  Created by Anton Bredykhin on 10/12/24.
//

struct Transaction {
    let id: Int
    let amount: Double
    let iso_currency_code: String
    let authorized_date: String?
    let date: String
    let category: String
    let pending: Bool
    let merchant_name: String?
    let name: String
}

struct MockTransactions {
    static let transaction1 = Transaction(id: 0, amount: 13.99, iso_currency_code: "USD", authorized_date: "2024-12-01", date: "2024-12-01", category: "Entertainment", pending: false, merchant_name: "AMC Theaters", name: "AMC")
    static let transaction2 = Transaction(id: 1, amount: 13.99, iso_currency_code: "USD", authorized_date: "2024-06-11", date: "2024-12-01", category: "Leisure", pending: true, merchant_name: "Beach Co", name: "AMC")
    static let transaction3 = Transaction(id: 2, amount: 27.42, iso_currency_code: "USD", authorized_date: "2024-02-22", date: "2024-12-01", category: "Transportation", pending: false, merchant_name: "ARCO Gas", name: "AMC")
}
