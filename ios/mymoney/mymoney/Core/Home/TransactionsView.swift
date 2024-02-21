//
//  TransactionsView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI

struct TransactionsView: View {
    
    @EnvironmentObject var userSessionService: UserSessionService

    var body: some View {
        Text(verbatim: "Transactions")
    }
}
