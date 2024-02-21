//
//  AccountsView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI


struct AccountsView: View {
    @State private var itemsRepository: ItemsRepository
    
    init(user: User) {
        _itemsRepository = .init(initialValue: .init(user: user))
    }
    
    var body: some View {
        ScrollView {
            Button {
                Task {
                    debugPrint("Add new account pressed!")
                    let linkToken = try await itemsRepository.getLinkToken()
                }
            } label: {
                Text("Link new account")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.primaryColor)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .shadow(radius: 2)
            }
            .padding(.top)
            LazyVStack(alignment: .leading) {
                
            }
        }
    }
}
