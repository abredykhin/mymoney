//
//  HeroCarouselView.swift
//  Bablo
//
//  Created by Antigravity on 12/23/25.
//

import SwiftUI

struct HeroCarouselView: View {
    @EnvironmentObject var accountsService: AccountsService
    @StateObject private var budgetService = BudgetService()
    
    // Placeholder data for now, will integrate real data for the first card
    @State private var cards: [HeroCardViewModel] = []
    @State private var selectedIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background stack effect (only one card behind, tighter)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 160)
                    .padding(.horizontal, 40)
                    .scaleEffect(0.95)
                    .offset(y: 12)
                    .opacity(0.4)
                    .zIndex(-1)
                
                TabView(selection: $selectedIndex) {
                    if cards.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                            HeroCardView(model: card)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 190)
            }
        }
        .background {
            // Expansive background glow (unclipped and layout-neutral)
            if !cards.isEmpty {
                let currentCard = cards[selectedIndex]
                let glowColor = currentCard.isPositive ? Color.green : Color.red
                
                Circle()
                    .fill(glowColor.opacity(0.4))
                    .frame(width: 800, height: 800) // Even larger
                    .blur(radius: 120)
                    .offset(x: -250, y: -300) // Positioned way up and left
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            setupCards()
            Task {
                try? await budgetService.fetchTotalBalance()
                updateRealData()
            }
        }
    }
    
    private func setupCards() {
        // Initial cards with placeholders
        cards = [
            HeroCardViewModel(
                title: "Net Available Cash",
                amount: budgetService.totalBalance?.balance ?? 0,
                monthlyChange: 0,
                isPositive: true,
                currencyCode: budgetService.totalBalance?.iso_currency_code ?? "USD"
            ),
            HeroCardViewModel(
                title: "Monthly Discretionary Budget",
                amount: 1200.0,
                monthlyChange: 300,
                isPositive: true,
                currencyCode: "USD"
            ),
            HeroCardViewModel(
                title: "Spending Breakdown",
                amount: 1850.0,
                monthlyChange: -80,
                isPositive: false,
                currencyCode: "USD"
            )
        ]
    }
    
    private func updateRealData() {
        if let totalBalance = budgetService.totalBalance {
            cards[0] = HeroCardViewModel(
                title: "Net Available Cash",
                amount: totalBalance.balance,
                monthlyChange: 320.0, // Hardcoded for now as per mockup, ideally should come from stats
                isPositive: true,
                currencyCode: totalBalance.iso_currency_code
            )
        }
    }
}

#Preview {
    HeroCarouselView()
        .environmentObject(AccountsService())
}
