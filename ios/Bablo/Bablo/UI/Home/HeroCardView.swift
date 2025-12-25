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
    
    init(
        title: String,
        amount: Double,
        monthlyChange: Double = 0,
        isPositive: Bool = true,
        currencyCode: String = "USD",
        subtitle: String? = nil
    ) {
        self.title = title
        self.amount = amount
        self.monthlyChange = monthlyChange
        self.isPositive = isPositive
        self.currencyCode = currencyCode
        self.subtitle = subtitle
    }
    
    var statusText: String {
        isPositive ? "Healthy Surplus" : "Budget Deficit"
    }
    
    var changeText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = monthlyChange.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        let amountString = formatter.string(from: NSNumber(value: abs(monthlyChange))) ?? ""
        return "\(isPositive ? "+" : "-")\(amountString) this month"
    }
}

struct HeroCardView: View {
    let model: HeroCardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(model.amount.rounded(.toNearestOrAwayFromZero), format: .currency(code: model.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 40, weight: .bold, design: .rounded))
            
            HStack(spacing: 6) {
                Image(systemName: model.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(model.isPositive ? .green : .red)
                
                Text(model.statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary) // Black in light mode
                
                Text("\(model.changeText)")
                    .font(.footnote)
                    .foregroundColor(model.isPositive ? .green : .red) // Green if positive
                
                if let subtitle = model.subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
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
