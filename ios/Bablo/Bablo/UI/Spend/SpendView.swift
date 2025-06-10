//
//  SpendView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 4/6/25.
//

import SwiftUI

// Helper for currency formatting
extension NumberFormatter {
    static func currency(code: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter
    }
}

struct SpendView: View {
    @State private var selectedDateRange: SpendDateRange = .week
    @StateObject private var budgetService = BudgetService()
    @State private var animateBars: Bool = false  // State to control animation trigger
    @State private var showingDetailSheet = false
    @State private var selectedCategoryForDetail: String?

    // Determine which value to display based on the selected range
    private func spendValue(for item: CategoryBreakdownItem, range: SpendDateRange) -> Double {
        switch range {
        case .week:
            return item.weekly_spend
        case .month:
            return item.monthly_spend
        case .year:
            return item.yearly_spend
        }
    }

    private var sortedSpendBreakdownItems: [CategoryBreakdownItem] {
        budgetService.spendBreakdownItems
            .filter { spendValue(for: $0, range: selectedDateRange) != 0 }
            .sorted {
                spendValue(for: $0, range: selectedDateRange)
                    > spendValue(for: $1, range: selectedDateRange)
            }
    }

    private var totalSpendForSelectedRange: Double {
        sortedSpendBreakdownItems.reduce(0) { result, item in
            result + spendValue(for: item, range: selectedDateRange)
        }
    }

    private func barColor(for index: Int, totalCount: Int) -> Color {
        guard totalCount > 0 else { return Color.gray.opacity(0.2) }

        let fraction = (totalCount <= 1) ? 0.0 : Double(index) / Double(totalCount - 1)

        // Hue: Red/Dark Orange (approx 0.0 - 0.08) to Light Yellow (approx 0.15)
        let startHue: Double = 0.05  // Start with a reddish-orange
        let endHue: Double = 0.15  // End with yellow
        let currentHue = startHue + (endHue - startHue) * fraction

        // Saturation: Keep it relatively vibrant
        let saturation: Double = 0.85

        // Brightness: Darker for top items, lighter for bottom items
        let startBrightness: Double = 0.80  // Darker, but still vibrant for orange/red
        let endBrightness: Double = 0.95  // Lighter for yellow
        let currentBrightness = startBrightness + (endBrightness - startBrightness) * fraction

        return Color(hue: currentHue, saturation: saturation, brightness: currentBrightness)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Use the SpendDateRange's displayName
                Picker("Date range", selection: $selectedDateRange) {
                    ForEach(SpendDateRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom)

                // Show loading or error state
                if budgetService.isLoadingBreakdown {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let error = budgetService.breakdownError {
                    Text("Error loading breakdown: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                } else if budgetService.spendBreakdownItems.isEmpty {
                    Text("No spending data available for the current year.")
                        .foregroundColor(.secondary)
                        .padding()
                } else if sortedSpendBreakdownItems.isEmpty {  // Check sorted list specifically
                    Text("No spending data for the selected period.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    let totalSpend = totalSpendForSelectedRange  // Cache for use in the loop
                    // Display the data using LazyVStack
                    LazyVStack(spacing: 10) {  // Adjusted spacing
                        ForEach(
                            Array(sortedSpendBreakdownItems.enumerated()), id: \.element.category
                        ) { index, item in
                            let currentSpend = spendValue(for: item, range: selectedDateRange)
                            let proportion = totalSpend > 0 ? (currentSpend / totalSpend) : 0

                            ZStack(alignment: .leading) {
                                // Bar Layer
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(
                                            barColor(
                                                for: index,
                                                totalCount: sortedSpendBreakdownItems.count)
                                        )
                                        // Width depends on animateBars state and proportion
                                        .frame(
                                            width: geometry.size.width
                                                * (animateBars ? proportion : 0)
                                        )
                                }

                                // Content Layer
                                HStack {
                                    Text(
                                        getTransactionCategoryDescription(
                                            transactionCategory: item.category
                                        )
                                    )
                                    Spacer()
                                    Text(
                                        currentSpend,  // Use the already fetched currentSpend
                                        format: .currency(code: "USD")
                                    )
                                    .monospaced()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)  // Adjusted padding
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                selectedCategoryForDetail = item.category
                                showingDetailSheet = true
                            }
                            // Optional: Give rows a consistent minimum height
                            // .frame(minHeight: 50)
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingDetailSheet) {
            if let category = selectedCategoryForDetail {
                CategorySpendDetailView(category: category)
            }
        }
        // Use .task with selectedDateRange as id to re-run on change or initial appearance
        .task(id: selectedDateRange) {
            // Step 1: Immediately set bars to 0 width by turning off animateBars.
            // This change itself is NOT animated by a withAnimation block here.
            animateBars = false

            // Step 2: Yield to allow SwiftUI to process the state change and re-render the bars at 0 width.
            // This is important so the subsequent animation starts from 0.
            await Task.yield()

            // Step 3: Fetch data for the selected range.
            try? await budgetService.fetchSpendBreakdown(period: selectedDateRange)

            // Step 4: After data is fetched and proportions are updated, trigger the animation
            // for bars to grow to their new size.
            // The withAnimation block here will animate the change of `animateBars` from false to true.
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5).delay(0.05)) {  // Kept delay for visual pause
                    animateBars = true
                }
            }
        }
        .navigationTitle("Spend")
    }
}

#if DEBUG
    struct SpendView_Previews: PreviewProvider {
        static var previews: some View {
            SpendView()
        }
    }
#endif
