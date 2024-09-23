//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI

struct HomeView: View {    
    @EnvironmentObject var bankAccountsService: BankAccountsService
    
    var body: some View {
        ScrollView {
            LinkButtonView()
                .padding(.top)
            BankAccountListView()
        }.refreshable {
            try? await bankAccountsService.refreshAccounts()
        }.task {
            try? await bankAccountsService.refreshAccounts()
        }
    }
}
