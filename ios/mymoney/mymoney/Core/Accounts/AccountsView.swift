//
//  AccountsView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI


struct AccountsView: View {
    @State var user: User
    
    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        ScrollView {
            LinkButtonView(user: user)
            .padding(.top)
            LazyVStack(alignment: .leading) {
                
            }
        }
    }
}
