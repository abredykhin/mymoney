//
//  ContentView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 12/17/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        Group {
            if (viewModel.currentUser != nil) {
                Print("ContentView: user is known, showing home screen")
                HomeView()
            } else {
                Print("ContentView: user is NOT known, showing login form")
                LoginView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let viewModel = AuthViewModel()
    
    static var previews: some View {
        ContentView()
            .environmentObject(viewModel)
    }
}
