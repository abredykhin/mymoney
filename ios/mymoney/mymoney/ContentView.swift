//
//  ContentView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 12/17/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: UserSessionService
    
    var body: some View {
        Group {
            if (service.currentUser != nil) {
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
    static let service = UserSessionService()
    
    static var previews: some View {
        ContentView()
            .environmentObject(service)
    }
}
