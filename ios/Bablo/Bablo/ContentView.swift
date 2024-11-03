//
//  ContentView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/10/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var userAccount: UserAccount

    var body: some View {
        if (userAccount.isSignedIn) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Overview", systemImage: "house")
                    }
            }
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
}
