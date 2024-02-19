//
//  User.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let token: String
}
