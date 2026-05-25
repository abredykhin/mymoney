//
//  ComingUpWidgetView.swift
//  Bablo
//

import SwiftUI

struct ComingUpWidgetView: View {
    @EnvironmentObject var subService: SubscriptionsService
    @Environment(\.babloTheme) private var theme
    
    private var calculator: ComingUpCalculator {
        // Safe default: use standard UTC timezone for database dates and local calendar to determine current day
        ComingUpCalculator(
            subscriptions: subService.allRecurringStreams,
            currentDate: Date(),
            timeZone: TimeZone(identifier: "UTC")!
        )
    }
    
    private var upcomingBills: [RecurringStream] {
        calculator.upcomingBills(withinDays: 14)
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: "Coming up" title, Sub-headline and "All >" button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Coming up")
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    
                    Text("\(upcomingBills.count) bills · next 14 days")
                        .font(theme.typography.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                
                Spacer()
                
                // "All >" Button (Visual representation only, non-interactive for now)
                HStack(spacing: 4) {
                    Text("All")
                        .font(theme.typography.body(size: 13, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(theme.colors.textTertiary.color)
                .padding(.top, 2)
            }
            
            // Content Card List or Empty State
            if upcomingBills.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.colors.textTertiary.color)
                        Text("No upcoming bills next 14 days")
                            .font(theme.typography.body(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcomingBills) { bill in
                            BillCell(bill: bill, calculator: calculator)
                        }
                    }
                    .padding(.horizontal, 2) // Prevents neobrutalist outline clipping
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(
                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                )
        }
        .shadow(
            color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04),
            radius: isPopArt ? 0 : 16,
            x: isPopArt ? 3 : 0,
            y: isPopArt ? 3 : 6
        )
    }
}

// MARK: - Bill Cell Widget

struct BillCell: View {
    let bill: RecurringStream
    let calculator: ComingUpCalculator
    
    @Environment(\.babloTheme) private var theme
    
    private var daysLeft: Int {
        calculator.daysRemaining(for: bill) ?? 0
    }
    
    private var badgeText: String {
        calculator.badgeText(for: daysLeft)
    }
    
    private var dayOfWeekText: String {
        guard let dateStr = bill.predictedNextDate,
              let date = calculator.parseDate(dateStr) else {
            return ""
        }
        return calculator.dayOfWeekDisplay(for: date)
    }
    
    private var iconName: String {
        let nameLower = (bill.merchantName ?? bill.description).lowercased()
        if nameLower.contains("spotify") {
            return "music.note"
        } else if nameLower.contains("netflix") {
            return "play.tv.fill"
        } else if nameLower.contains("canva") {
            return "paintpalette.fill"
        } else if nameLower.contains("figma") {
            return "scribble.variable"
        } else if nameLower.contains("verizon") {
            return "phone.fill"
        } else if nameLower.contains("rent") {
            return "house.fill"
        } else if nameLower.contains("sub") || nameLower.contains("bill") {
            return "doc.text.fill"
        }
        
        // Category fallbacks
        let category = bill.personalFinanceCategory?.lowercased() ?? ""
        if category.contains("entertainment") {
            return "tv.fill"
        } else if category.contains("rent") || category.contains("home") {
            return "house.fill"
        } else if category.contains("utilities") {
            return "bolt.fill"
        }
        
        return "creditcard.fill"
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Icon and Badge
            HStack(alignment: .center) {
                // Icon frame
                ZStack {
                    if isPopArt {
                        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                            .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.colors.surfaceMuted.color)
                            .frame(width: 28, height: 28)
                    }
                    
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                
                Spacer()
                
                // IN XD Badge
                if !badgeText.isEmpty {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.colors.danger.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(theme.colors.danger.color.opacity(0.12))
                        )
                }
            }
            
            Spacer(minLength: 0)
            
            // Merchant Name
            Text(bill.merchantName ?? bill.description)
                .font(theme.typography.body(size: 13, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
            
            // Bottom Row: Price and Weekday
            HStack(alignment: .firstTextBaseline) {
                Text(formatCurrency(bill.averageAmount))
                    .font(theme.typography.body(size: 12, weight: isPopArt ? .black : .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                
                Spacer()
                
                Text(dayOfWeekText)
                    .font(theme.typography.body(size: 10, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
            }
        }
        .padding(10)
        .frame(width: 110, height: 95)
        .background(theme.colors.surface.color)
        .cornerRadius(theme.metrics.controlCornerRadius)
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                .stroke(
                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                    lineWidth: isPopArt ? 1.5 : 1.0
                )
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
        } else {
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
        }
    }
}

// MARK: - Previews

struct ComingUpWidgetPreviewWrapper: View {
    let theme: BabloTheme
    let isEmpty: Bool
    let subService: SubscriptionsService
    
    init(theme: BabloTheme, isEmpty: Bool) {
        self.theme = theme
        self.isEmpty = isEmpty
        self.subService = SubscriptionsService()
        
        if !isEmpty {
            // Seed upcoming bills matching the target mock mockup dates exactly
            let calendar = Calendar.current
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            let datePlus2 = calendar.date(byAdding: .day, value: 2, to: today)!
            let datePlus6 = calendar.date(byAdding: .day, value: 6, to: today)!
            let datePlus8 = calendar.date(byAdding: .day, value: 8, to: today)!
            
            self.subService.allRecurringStreams = [
                RecurringStream(
                    id: 1, plaidStreamId: "plaid_1", description: "Spotify Premium",
                    merchantName: "Spotify", personalFinanceCategory: "ENTERTAINMENT",
                    personalFinanceSubcategory: "MUSIC", frequency: "MONTHLY",
                    averageAmount: 11.99, monthlyAmount: 11.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus2),
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 2, plaidStreamId: "plaid_2", description: "Rent",
                    merchantName: "Rent", personalFinanceCategory: "RENT_OR_MORTGAGE",
                    personalFinanceSubcategory: nil, frequency: "MONTHLY",
                    averageAmount: 1450.0, monthlyAmount: 1450.0, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus6),
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                ),
                RecurringStream(
                    id: 3, plaidStreamId: "plaid_3", description: "Verizon Wireless",
                    merchantName: "Verizon", personalFinanceCategory: "UTILITIES",
                    personalFinanceSubcategory: nil, frequency: "MONTHLY",
                    averageAmount: 65.0, monthlyAmount: 65.0, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus8),
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil
                )
            ]
        }
    }
    
    var body: some View {
        ComingUpWidgetView()
            .environmentObject(subService)
            .babloTheme(theme)
            .padding()
            .frame(width: 358)
            .background(theme == .pop ? Color(hex: "#FFF09A") : Color(hex: "#F8F5EF"))
    }
}

#Preview("Coming Up Normal") {
    ComingUpWidgetPreviewWrapper(theme: .normal, isEmpty: false)
}

#Preview("Coming Up Pop") {
    ComingUpWidgetPreviewWrapper(theme: .pop, isEmpty: false)
}

#Preview("Coming Up Normal Empty") {
    ComingUpWidgetPreviewWrapper(theme: .normal, isEmpty: true)
}

#Preview("Coming Up Pop Empty") {
    ComingUpWidgetPreviewWrapper(theme: .pop, isEmpty: true)
}
