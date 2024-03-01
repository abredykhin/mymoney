//
//  HomeView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import SwiftUI

struct HomeView: View {
    
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("", systemImage: "checkmark.circle")
                }
            TransactionsView()
                .tabItem {
                    Label("", systemImage: "questionmark.diamond")
                }
        }
    }
}
