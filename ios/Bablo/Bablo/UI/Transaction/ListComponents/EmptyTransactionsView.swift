//
//  EmptyTransactionsView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 12/23/25.
//

import SwiftUI

struct EmptyTransactionsView: View {
    let refreshAction: () async -> Void
    
    var body: some View {
        ZStack {
            ScrollView {
                // Empty view to allow pull-to-refresh
                Color.clear
                    .frame(height: 1) // Minimal height to ensure scrollability?
                    // Actually EmptyView in ScrollView might not be scrollable if content is 0.
                    // Better to put a wrapper.
            }
            .refreshable {
                await refreshAction()
            }
            
            VStack {
                Text("No transactions found")
                    .font(.headline)
                Text("Pull to refresh")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}
