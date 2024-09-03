//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI

struct HomeView: View {    
    @EnvironmentObject var bankAccounts: BankAccounts
    
    var body: some View {
        ScrollView {
            LinkButtonView()
                .padding(.top)
            BankAccountListView()
        }.task {
            try? await bankAccounts.refreshAccounts()
        }
    }
}
