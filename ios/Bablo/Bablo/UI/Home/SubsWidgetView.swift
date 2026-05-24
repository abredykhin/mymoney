//
//  SubsWidgetView.swift
//  Bablo
//

import SwiftUI

struct SubsWidgetView: View {
    @EnvironmentObject var subService: SubscriptionsService
    @EnvironmentObject var transactionsService: TransactionsService
    @Environment(\.babloTheme) private var theme

    private var totalMonthlyCost: Double {
        subService.subscriptions.reduce(0.0) { $0 + $1.monthlyAmount }
    }

    private var idleCount: Int {
        subService.idleCount
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        HomeWidgetCard(
            title: "SUBS",
            badge: idleCount > 0 ? "!\(idleCount)" : nil,
            badgeColor: theme.colors.danger.color
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Large monthly total amount
                Text(formatCurrency(totalMonthlyCost))
                    .font(.system(size: 30, weight: isPopArt ? .black : .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Subtitle: per month · N idle
                Text("per month · \(idleCount) idle")
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(1)
                    .frame(height: 32, alignment: .topLeading)

                // Overlapping Circle Avatars row
                HStack(spacing: -6) {
                    let activeSubs = subService.subscriptions
                    ForEach(activeSubs.prefix(4)) { sub in
                        let name = sub.merchantName ?? sub.description
                        let logoUrl = findLogoUrl(for: sub.merchantName, description: sub.description)
                        
                        CircleAvatarView(name: name, logoUrl: logoUrl)
                            .overlay {
                                Circle()
                                    .stroke(theme.colors.surface.color, lineWidth: 1.5)
                            }
                    }
                    
                    if activeSubs.count > 4 {
                        Text("+\(activeSubs.count - 4)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                            .frame(width: 24, height: 24)
                            .background(theme.colors.surfaceMuted.color)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(theme.colors.surface.color, lineWidth: 1.5)
                            }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    /// Dynamically resolve a logo URL using the transactions cache
    private func findLogoUrl(for merchantName: String?, description: String) -> String? {
        let txs = transactionsService.transactions
        if let merchant = merchantName,
           let match = txs.first(where: { ($0.merchantName ?? "").localizedCaseInsensitiveContains(merchant) }),
           let url = match.logoUrl {
            return url
        }
        if let match = txs.first(where: { $0.name.localizedCaseInsensitiveContains(description) }),
           let url = match.logoUrl {
            return url
        }
        return nil
    }
}

// MARK: - Circle Avatar Widget

struct CircleAvatarView: View {
    let name: String
    let logoUrl: String?
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        ZStack {
            if let logoUrlString = logoUrl, let url = URL(string: logoUrlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Circle())
                } placeholder: {
                    initialsPlaceholder
                }
                .frame(width: 24, height: 24)
            } else {
                initialsPlaceholder
            }
        }
    }
    
    private var initialsPlaceholder: some View {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = cleanName.first.map { String($0).uppercased() } ?? "S"
        let brandInfo = resolveBrandInfo(for: cleanName)
        
        return Text(initial)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(brandInfo.color)
            .clipShape(Circle())
    }
    
    private struct BrandInfo {
        let color: Color
    }
    
    /// Map curated brand-specific background colors or generate adaptive color via hash
    private func resolveBrandInfo(for name: String) -> BrandInfo {
        let nameLower = name.lowercased()
        if nameLower.contains("spotify") {
            return BrandInfo(color: Color(hex: "#1DB954") ?? .green)
        } else if nameLower.contains("netflix") {
            return BrandInfo(color: Color(hex: "#221F1F") ?? .black)
        } else if nameLower.contains("canva") {
            return BrandInfo(color: Color(hex: "#7D2AE8") ?? .purple)
        } else if nameLower.contains("figma") {
            return BrandInfo(color: Color(hex: "#F24E1E") ?? .pink)
        } else if nameLower.contains("apple") {
            return BrandInfo(color: Color(hex: "#A2AAAD") ?? .gray)
        } else if nameLower.contains("verizon") {
            return BrandInfo(color: Color(hex: "#CD040B") ?? .red)
        } else if nameLower.contains("rent") {
            return BrandInfo(color: Color(hex: "#2A82E6") ?? .blue)
        }
        
        // Dynamic hash-based color palette to keep fallback circles vibrant
        let colors: [Color] = [
            .pink, .purple, .indigo, .blue, .cyan, .teal, .orange, .red, .gray
        ]
        let hash = abs(name.hashValue)
        let color = colors[hash % colors.count]
        return BrandInfo(color: color)
    }
}

// MARK: - Previews

struct SubsWidgetPreviewWrapper: View {
    let theme: BabloTheme
    let isEmpty: Bool
    let subService: SubscriptionsService
    let transactionsService: TransactionsService

    init(theme: BabloTheme, isEmpty: Bool) {
        self.theme = theme
        self.isEmpty = isEmpty
        self.subService = SubscriptionsService()
        self.transactionsService = TransactionsService()
        
        if !isEmpty {
            self.subService.idleCount = 2
            // Seed a realistic subscriptions array that sums up to exactly $47.83
            self.subService.subscriptions = [
                RecurringStream(
                    id: 1, plaidStreamId: "plaid_1", description: "Spotify Premium",
                    merchantName: "Spotify", personalFinanceCategory: "ENTERTAINMENT",
                    personalFinanceSubcategory: "MUSIC", frequency: "MONTHLY",
                    averageAmount: 11.99, monthlyAmount: 11.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 2, plaidStreamId: "plaid_2", description: "Netflix Standard",
                    merchantName: "Netflix", personalFinanceCategory: "ENTERTAINMENT",
                    personalFinanceSubcategory: "VIDEO", frequency: "MONTHLY",
                    averageAmount: 12.99, monthlyAmount: 12.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 3, plaidStreamId: "plaid_3", description: "Canva Pro",
                    merchantName: "Canva", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CREATIVE", frequency: "MONTHLY",
                    averageAmount: 12.85, monthlyAmount: 12.85, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 4, plaidStreamId: "plaid_4", description: "Figma Team",
                    merchantName: "Figma", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "DESIGN", frequency: "MONTHLY",
                    averageAmount: 10.00, monthlyAmount: 10.00, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 5, plaidStreamId: "plaid_5", description: "Adobe CC",
                    merchantName: "Adobe", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CREATIVE", frequency: "MONTHLY",
                    averageAmount: 54.99, monthlyAmount: 54.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 6, plaidStreamId: "plaid_6", description: "Google One",
                    merchantName: "Google", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CLOUD", frequency: "MONTHLY",
                    averageAmount: 1.99, monthlyAmount: 1.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                )
            ]
        }
    }

    var body: some View {
        SubsWidgetView()
            .environmentObject(subService)
            .environmentObject(transactionsService)
            .babloTheme(theme)
            .frame(width: 170)
            .padding()
            .background(theme == .pop ? Color(hex: "#FFF09A") : Color(hex: "#F8F5EF"))
    }
}

#Preview("Subs Normal Regular") {
    SubsWidgetPreviewWrapper(theme: .normal, isEmpty: false)
}

#Preview("Subs Pop Regular") {
    SubsWidgetPreviewWrapper(theme: .pop, isEmpty: false)
}

#Preview("Subs Normal Empty") {
    SubsWidgetPreviewWrapper(theme: .normal, isEmpty: true)
}

#Preview("Subs Pop Empty") {
    SubsWidgetPreviewWrapper(theme: .pop, isEmpty: true)
}
