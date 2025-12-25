//
//  HeroCarouselView.swift
//  Bablo
//
//  Created by Antigravity on 12/23/25.
//

import SwiftUI

struct HeroCarouselView: View {
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var budgetService: BudgetService
    
    @State private var cards: [HeroCardViewModel] = []
    @State private var selectedIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background stack effect
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
            // Expansive background glow
            let glowColor: Color = {
                if !cards.isEmpty && selectedIndex < cards.count {
                    return cards[selectedIndex].isPositive ? .green : .red
                }
                return .blue
            }()
            
            Circle()
                .fill(glowColor.opacity(0.4))
                .frame(width: 800, height: 800)
                .blur(radius: 120)
                .offset(x: -250, y: -300)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .onAppear {
            setupCards()
            Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { try? await budgetService.fetchTotalBalance() }
                    group.addTask { try? await budgetService.fetchSpendingBreakdown(range: .month) }
                    group.addTask { await budgetService.fetchBudgetSummary() }
                }
                updateRealData()
            }
        }
    }
    
    private func setupCards() {
        cards = [
            HeroCardViewModel(
                title: "Net Available Cash",
                amount: budgetService.totalBalance?.balance ?? 0,
                monthlyChange: 0,
                isPositive: true,
                currencyCode: budgetService.totalBalance?.iso_currency_code ?? "USD"
            )
        ]
    }
    
    private func updateRealData() {
        if let totalBalance = budgetService.totalBalance {
            self.cards = [HeroCardViewModel(
                title: "Net Available Cash",
                amount: totalBalance.balance,
                monthlyChange: 0,
                isPositive: true,
                currencyCode: totalBalance.iso_currency_code
            )]
        }
    }
}

//#Preview {
//    HeroCarouselView()
//        .environmentObject(AccountsService())
//}
