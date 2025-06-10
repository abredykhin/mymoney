//
//  CatefogorySpendDetail.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/9/25.
//

import SwiftUI

struct CategorySpendDetailView: View {
    var category: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("Details for \(getTransactionCategoryDescription(transactionCategory: category))")
                .font(.headline)
                .padding()
            // Add more detailed content here based on the category
            Spacer()
        }
        // Optional: Add a frame and background for debugging to see the view's bounds
        // .frame(maxWidth: .infinity, maxHeight: .infinity)
        // .background(Color.yellow.opacity(0.2))
    }
}

#Preview {
    CategorySpendDetailView(category: "Household")
}
