//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let name = userAccount.currentUser?.name {
                    VStack(spacing: 8) {
                        Text("Hello,")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                }
                
                List {
                    Section {
                        Button(action: handleSignOut) {
                            HStack {
                                Text("Sign Out")
                                    .font(.body)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.red)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

#Preview {
    let mockAccount = UserAccount()
    mockAccount.currentUser = User(id: "123", name: "Test User", token: "abc123")
    return ProfileView()
        .environmentObject(mockAccount)
}
