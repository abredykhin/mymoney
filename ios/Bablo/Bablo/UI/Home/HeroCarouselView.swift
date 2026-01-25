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
                RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 160)
                    .padding(.horizontal, Spacing.xxxl)
                    .scaleEffect(0.95)
                    .offset(y: Spacing.md)
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
                .tabViewStyle(.page(indexDisplayMode: cards.count > 1 ? .always : .never))
                .frame(height: 190)
            }
        }
        .background {
            // Expansive background glow
            let glowColor: Color = {
                if !cards.isEmpty && selectedIndex < cards.count {
                    return cards[selectedIndex].isPositive ? ColorPalette.glowPositive : ColorPalette.glowNegative
                }
                return ColorPalette.info
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
                // 1. Fetch budget summary FIRST to load patterns (bills/income)
                await budgetService.fetchBudgetSummary()
                
                // 2. Then fetch breakdown (depends on patterns to filter bills) & balance
                // We can run these in parallel now that patterns are loaded, or just sequentially for simplicity
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { try? await budgetService.fetchTotalBalance() }
                    group.addTask { try? await budgetService.fetchSpendingBreakdown(range: .month) }
                }
                
                updateRealData()
            }
        }
    }
    
    private func setupCards() {
        let balance = budgetService.totalBalance?.balance ?? 0
        let isDistressed = balance < 0
        
        cards = [
            HeroCardViewModel(
                title: "Net Available Cash",
                amount: balance,
                monthlyChange: 0,
                isPositive: !isDistressed,
                currencyCode: budgetService.totalBalance?.iso_currency_code ?? "USD",
                overrideStatusText: isDistressed ? "Negative Balance" : nil
            )
        ]
    }
    
    private func updateRealData() {
        if let totalBalance = budgetService.totalBalance {
            let isDistressed = totalBalance.balance < 0
            self.cards = [HeroCardViewModel(
                title: "Net Available Cash",
                amount: totalBalance.balance,
                monthlyChange: 0,
                isPositive: !isDistressed,
                currencyCode: totalBalance.iso_currency_code,
                overrideStatusText: isDistressed ? "Negative Balance" : nil
            )]
        }
    }
}

//#Preview {
//    HeroCarouselView()
//        .environmentObject(AccountsService())
//}
