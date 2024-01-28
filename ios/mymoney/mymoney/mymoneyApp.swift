//
//  mymoneyApp.swift
//  mymoney
//
//  Created by Anton Bredykhin on 12/17/23.
//

import SwiftUI

@main
struct mymoneyApp: App {
    @StateObject var authViewModel = AuthViewModel()
    
    init() {
        // initialize Plaid and other stuff
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
