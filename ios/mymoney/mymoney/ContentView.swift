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
                HomeView()
            } else {
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
