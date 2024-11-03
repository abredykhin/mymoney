//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    
    var body: some View {
        List {
            Button(action: handleSignOut) {
                Text("Sign Out")
                    .foregroundColor(.red)
                    .font(.headline)
            }
        }
        .navigationTitle("Profile")
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

#Preview {
    ProfileView()
}
