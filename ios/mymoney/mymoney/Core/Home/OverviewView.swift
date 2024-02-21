//
//  OverviewView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import SwiftUI

struct OverviewView: View {
    
    @EnvironmentObject var userSessionService: UserSessionService
    
    var body: some View {
        ScrollView {
            AccountsView(user: userSessionService.currentUser!)
        }
    }
}
