//
//  HeroCardView.swift
//  Bablo
//
//  Created by Antigravity on 12/23/25.
//

import SwiftUI

struct HeroCardViewModel: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let monthlyChange: Double
    let isPositive: Bool
    let currencyCode: String
    let subtitle: String?
    let overrideStatusText: String?
    let showArrow: Bool
    
    init(
        title: String,
        amount: Double,
        monthlyChange: Double = 0,
        isPositive: Bool = true,
        currencyCode: String = "USD",
        subtitle: String? = nil,
        overrideStatusText: String? = nil,
        showArrow: Bool = true
    ) {
        self.title = title
        self.amount = amount
        self.monthlyChange = monthlyChange
        self.isPositive = isPositive
        self.currencyCode = currencyCode
        self.subtitle = subtitle
        self.overrideStatusText = overrideStatusText
        self.showArrow = showArrow
    }
    
    var statusText: String {
        if let override = overrideStatusText {
            return override
        }
        return isPositive ? "Healthy Surplus" : "Budget Deficit"
    }
    
    var changeText: String? {
        guard monthlyChange != 0 else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = monthlyChange.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        let amountString = formatter.string(from: NSNumber(value: abs(monthlyChange))) ?? ""
        return "\(monthlyChange > 0 ? "+" : "-")\(amountString) this month"
    }
}

struct HeroCardView: View {
    let model: HeroCardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(model.title)
                .font(Typography.footnote)
                .foregroundColor(ColorPalette.textSecondary)

            Text(model.amount.rounded(.toNearestOrAwayFromZero), format: .currency(code: model.currencyCode).precision(.fractionLength(0)))
                .font(Typography.h3.monospaced())

            HStack(spacing: Spacing.xs) {
                if model.showArrow {
                    Image(systemName: model.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(model.isPositive ? ColorPalette.success : ColorPalette.error)
                }

                Text(model.statusText)
                    .font(Typography.footnote)
                    .foregroundColor(ColorPalette.textPrimary)

                if let changeText = model.changeText {
                    Text(changeText)
                        .font(.system(size: 11))
                        .foregroundColor(model.isPositive ? ColorPalette.success : ColorPalette.error)
                }

                if let subtitle = model.subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .glassCard()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        VStack {
            HeroCardView(model: HeroCardViewModel(
                title: "Net Available Cash",
                amount: 8420.00,
                monthlyChange: 320.0,
                isPositive: true,
                currencyCode: "USD"
            ))
            
            HeroCardView(model: HeroCardViewModel(
                title: "Monthly Discretionary Budget",
                amount: 1200.00,
                monthlyChange: -150.0,
                isPositive: false,
                currencyCode: "USD"
            ))
        }
    }
}
