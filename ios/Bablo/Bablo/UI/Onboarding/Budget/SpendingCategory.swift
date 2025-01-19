//
//  SpendingCategory.swift
//  Bablo
//
//  Created by Anton Bredykhin on 1/18/25.
//

import SwiftUI

struct SpendingCategory: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
}
