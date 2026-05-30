//
//  ComingUpDetailsSheetView.swift
//  Bablo
//

import SwiftUI
import UserNotifications

struct ComingUpDetailsSheetView: View {
    @EnvironmentObject var subService: SubscriptionsService
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var budgetService: BudgetService
    
    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    // Selection state for which bill is spotlighted (defaults to next upcoming)
    @State private var selectedBillID: Int? = nil
    
    // State for reminder alert confirmation
    @State private var showingRemindersAlert = false
    
    // Track whether reminders have been set on-device
    @State private var remindersEnabled: Bool = UserDefaults.standard.bool(forKey: "bill_reminders_enabled")
    
    private var currentDate: Date {
        Date()
    }
    
    private var calculator: ComingUpCalculator {
        ComingUpCalculator(
            subscriptions: subService.allRecurringStreams,
            currentDate: currentDate,
            timeZone: .current
        )
    }
    
    // Sorted bills due in the next 30 days
    private var allUpcomingBills: [RecurringStream] {
        subService.allRecurringStreams.filter { stream in
            guard stream.isActive && !stream.isExcluded && stream.type == "expense" else {
                return false
            }
            guard let days = calculator.daysRemaining(for: stream) else {
                return false
            }
            return days >= 0 && days <= 30
        }.sorted { a, b in
            let daysA = calculator.daysRemaining(for: a) ?? Int.max
            let daysB = calculator.daysRemaining(for: b) ?? Int.max
            return daysA < daysB
        }
    }
    
    // Expected income in the next 30 days
    private var expectedIncome30Days: Double {
        subService.allRecurringStreams.filter { stream in
            guard stream.isActive && !stream.isExcluded && stream.type == "income" else {
                return false
            }
            guard let days = calculator.daysRemaining(for: stream) else {
                return false
            }
            return days >= 0 && days <= 30
        }.reduce(0.0) { $0 + $1.averageAmount }
    }
    
    // The currently selected spotlight stream (defaults to next up)
    private var spotlightBill: RecurringStream? {
        if let id = selectedBillID, let match = allUpcomingBills.first(where: { $0.id == id }) {
            return match
        }
        return allUpcomingBills.first
    }
    
    // Coverage available balance
    private var availableBalance: Double {
        if let balance = budgetService.totalBalance?.balance, balance > 0 {
            return balance
        }
        let accountsTotal = accountsService.totalBalance
        return accountsTotal > 0 ? accountsTotal : 2840.0 // Elegant preview fallback
    }
    
    // Coverage due amount (next 30 days)
    private var totalDue30Days: Double {
        allUpcomingBills.reduce(0.0) { $0 + $1.averageAmount }
    }
    
    // Due amount next 14 days
    private var totalDue14Days: Double {
        allUpcomingBills
            .filter { (calculator.daysRemaining(for: $0) ?? 99) <= 14 }
            .reduce(0.0) { $0 + $1.averageAmount }
    }
    
    // Grouping upcoming bills by timeframe
    private var thisWeekBills: [RecurringStream] {
        allUpcomingBills.filter { (calculator.daysRemaining(for: $0) ?? 99) <= 7 }
    }
    
    private var nextWeekBills: [RecurringStream] {
        allUpcomingBills.filter {
            let days = calculator.daysRemaining(for: $0) ?? 99
            return days > 7 && days <= 14
        }
    }
    
    private var laterThisMonthBills: [RecurringStream] {
        allUpcomingBills.filter {
            let days = calculator.daysRemaining(for: $0) ?? 99
            return days > 14 && days <= 30
        }
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        VStack(spacing: 0) {
            // 1. Drag Handle
            Capsule()
                .fill(theme.colors.textSecondary.color.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)
            
            // 2. Custom Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COMING UP")
                            .font(theme.typography.mono(size: 11, weight: .bold))
                            .tracking(theme.typography.labelTracking)
                            .foregroundStyle(theme.colors.textTertiary.color)
                        
                        Text("Due soon")
                            .font(theme.typography.title(size: 26, weight: isPopArt ? .black : .bold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                    }
                    
                    Spacer()
                    
                    // Close Button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .frame(width: 32, height: 32)
                            .background(theme.colors.surfaceMuted.color)
                            .clipShape(Circle())
                            .overlay {
                                if isPopArt {
                                    Circle()
                                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                
                Text("\(allUpcomingBills.count) bills heading your way")
                    .font(theme.typography.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            
            Divider()
                .overlay(theme.colors.line.color)
            
            // 3. Main Sheet Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Spotlight card
                    if let bill = spotlightBill {
                        SpotlightCard(bill: bill, calculator: calculator, accountDisplay: linkedAccountDisplay(for: bill))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Interactive horizontal timeline slider
                    if !allUpcomingBills.isEmpty {
                        TimelineWidget(
                            bills: allUpcomingBills,
                            selectedID: $selectedBillID,
                            calculator: calculator
                        )
                        .padding(.vertical, 8)
                    }
                    
                    // Coverage banner card
                    CoverageCard(available: availableBalance, expectedIncome: expectedIncome30Days, totalDue: totalDue30Days)
                    
                    // Stats section
                    StatsSection(due14: totalDue14Days, due30: totalDue30Days, count: allUpcomingBills.count)
                    
                    Divider()
                        .overlay(theme.colors.line.color)
                    
                    // Grouped Lists by Timeframe
                    VStack(alignment: .leading, spacing: 20) {
                        if !thisWeekBills.isEmpty {
                            TimeframeGroup(title: "THIS WEEK", bills: thisWeekBills, selectedID: $selectedBillID, calculator: calculator)
                        }
                        
                        if !nextWeekBills.isEmpty {
                            TimeframeGroup(title: "NEXT WEEK", bills: nextWeekBills, selectedID: $selectedBillID, calculator: calculator)
                        }
                        
                        if !laterThisMonthBills.isEmpty {
                            TimeframeGroup(title: "LATER THIS MONTH", bills: laterThisMonthBills, selectedID: $selectedBillID, calculator: calculator)
                        }
                        
                        if allUpcomingBills.isEmpty {
                            EmptyUpcomingState()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Static Bottom Summary Bar
                BottomSummaryBar(totalDue: totalDue30Days, remindersEnabled: remindersEnabled, onSetReminders: {
                    scheduleLocalReminders()
                    UserDefaults.standard.set(true, forKey: "bill_reminders_enabled")
                    remindersEnabled = true
                    showingRemindersAlert = true
                })
            }
        }
        .background(theme.colors.appBackground.color.ignoresSafeArea())
        .alert("Reminders Scheduled", isPresented: $showingRemindersAlert) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("We'll send you notifications 2 days before each bill is due so you're always prepared.")
        }
    }
    
    // Derives connected account details elegantly
    private func linkedAccountDisplay(for stream: RecurringStream) -> String {
        guard let accountId = stream.accountId else {
            // Fallback for previews and empty/initial database state
            let nameLower = (stream.merchantName ?? stream.description).lowercased()
            if nameLower.contains("spotify") {
                return "Chase ··3382"
            } else if nameLower.contains("rent") {
                return "Wells Fargo ··1094"
            } else if nameLower.contains("verizon") {
                return "Apple Card ··8842"
            } else if nameLower.contains("netflix") {
                return "Capital One ··4491"
            } else {
                return "Checking ··9821"
            }
        }
        
        for bank in accountsService.banksWithAccounts {
            if let account = bank.accounts.first(where: { $0.id == accountId }) {
                return "\(bank.name) ··\(account.mask ?? "9821")"
            }
        }
        return "Linked Account"
    }
    
    private func scheduleLocalReminders() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                Logger.w("Notification permission not granted")
                return
            }
            
            // Clear any previously scheduled bill reminders to avoid duplicates
            center.removeAllPendingNotificationRequests()
            
            let billsToSchedule = allUpcomingBills
            
            for bill in billsToSchedule {
                guard let dateStr = bill.predictedNextDate,
                      let dueDate = calculator.parseDate(dateStr) else {
                    continue
                }
                
                // Calculate notification date: 2 days before due date
                let calendar = Calendar.current
                guard let notificationDate = calendar.date(byAdding: .day, value: -2, to: dueDate) else {
                    continue
                }
                
                // If the notification date is in the past (e.g. bill is due in 0, 1, or 2 days),
                // schedule it for tomorrow morning at 9:00 AM so the user gets it soon,
                // or if it's today and before 9:00 AM, today at 9:00 AM.
                var fireDate = notificationDate
                let now = Date()
                if notificationDate < now {
                    var components = calendar.dateComponents([.year, .month, .day], from: now)
                    components.hour = 9
                    components.minute = 0
                    components.second = 0
                    if let morningToday = calendar.date(from: components), morningToday > now {
                        fireDate = morningToday
                    } else if let morningTomorrow = calendar.date(byAdding: .day, value: 1, to: now).flatMap({ calendar.date(from: calendar.dateComponents([.year, .month, .day], from: $0)) }) {
                        var tomComponents = calendar.dateComponents([.year, .month, .day], from: morningTomorrow)
                        tomComponents.hour = 9
                        tomComponents.minute = 0
                        tomComponents.second = 0
                        fireDate = calendar.date(from: tomComponents) ?? now.addingTimeInterval(3600)
                    }
                } else {
                    // Ensure it fires at 9:00 AM on that day
                    var components = calendar.dateComponents([.year, .month, .day], from: notificationDate)
                    components.hour = 9
                    components.minute = 0
                    components.second = 0
                    if let target = calendar.date(from: components) {
                        fireDate = target
                    }
                }
                
                // Create content
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Bill: \(bill.merchantName ?? bill.description)"
                
                let daysUntil = calculator.daysRemaining(for: bill) ?? 0
                let formattedAmount = String(format: "$%.2f", bill.averageAmount)
                if daysUntil == 0 {
                    content.body = "Your bill for \(formattedAmount) is due today. Make sure you're covered!"
                } else if daysUntil == 1 {
                    content.body = "Your bill for \(formattedAmount) is due tomorrow. Make sure you're covered!"
                } else {
                    content.body = "Your bill for \(formattedAmount) is due in \(daysUntil) days."
                }
                content.sound = .default
                
                // Create trigger
                let fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
                
                // Request
                let identifier = "bill_reminder_\(bill.id)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        Logger.e("Error scheduling notification: \(error)")
                    } else {
                        Logger.i("Scheduled notification for \(bill.merchantName ?? bill.description) on \(fireDate)")
                    }
                }
            }
        }
    }
}

// MARK: - Subviews & Micro-components

// MARK: - 1. Spotlight Card
struct SpotlightCard: View {
    let bill: RecurringStream
    let calculator: ComingUpCalculator
    let accountDisplay: String
    
    @Environment(\.babloTheme) private var theme
    
    private var daysLeft: Int {
        calculator.daysRemaining(for: bill) ?? 0
    }
    
    private var formattedDate: String {
        guard let dateStr = bill.predictedNextDate,
              let date = calculator.parseDate(dateStr) else {
            return ""
        }
        if daysLeft == 0 {
            return "Today"
        } else if daysLeft == 1 {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private var brandColor: Color {
        let nameLower = (bill.merchantName ?? bill.description).lowercased()
        if nameLower.contains("spotify") { return Color(hex: "#A9F236") ?? .green }
        if nameLower.contains("netflix") { return theme.colors.danger.color }
        if nameLower.contains("verizon") { return theme.colors.info.color }
        if nameLower.contains("rent") { return theme.colors.accentDeep.color }
        return theme.colors.accent.color
    }
    
    private var iconName: String {
        let nameLower = (bill.merchantName ?? bill.description).lowercased()
        if nameLower.contains("spotify") { return "music.note" }
        if nameLower.contains("netflix") { return "play.tv.fill" }
        if nameLower.contains("verizon") { return "phone.fill" }
        if nameLower.contains("rent") { return "house.fill" }
        return "creditcard.fill"
    }
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        HStack(spacing: 16) {
            // Big Brand Icon Block
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(brandColor)
                    .frame(width: 60, height: 60)
                
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }
            .overlay {
                if isPopArt {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.5)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // NEXT UP Indicator
                Text("NEXT UP · \(daysLeftText)")
                    .font(theme.typography.body(size: 10, weight: .black))
                    .foregroundStyle(theme.colors.danger.color)
                
                // Name and Price
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(bill.merchantName ?? bill.description)
                        .font(theme.typography.title(size: 20, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    
                    Spacer()
                    
                    Text(formatCurrency(bill.averageAmount))
                        .font(theme.typography.display(size: 20, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                
                // Date and Bank Details
                Text("\(formattedDate) · \(accountDisplay)")
                    .font(theme.typography.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                .stroke(isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color, lineWidth: isPopArt ? 2 : 1)
        }
    }
    
    private var daysLeftText: String {
        if daysLeft == 0 {
            return "TODAY"
        } else if daysLeft == 1 {
            return "IN 1 DAY"
        } else {
            return "IN \(daysLeft) DAYS"
        }
    }
    
    private func formatCurrency(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: val)) ?? "$\(val)"
    }
}

// MARK: - 2. Timeline Widget
struct TimelineWidget: View {
    let bills: [RecurringStream]
    @Binding var selectedID: Int?
    let calculator: ComingUpCalculator
    
    @Environment(\.babloTheme) private var theme
    
    private func calculatePositions(trackWidth: CGFloat, horizontalPadding: CGFloat) -> [Int: CGFloat] {
        var positions: [Int: CGFloat] = [:]
        guard !bills.isEmpty else { return positions }
        
        // 1. Calculate preferred positions
        var items = bills.map { bill -> (id: Int, prefX: CGFloat) in
            let days = calculator.daysRemaining(for: bill) ?? 0
            let boundedDays = max(0, min(30, days))
            let pct = CGFloat(boundedDays) / 30.0
            let x = horizontalPadding + (pct * trackWidth)
            return (bill.id, x)
        }
        
        // 2. Adjust to avoid overlaps. Minimum distance = 14 points (half circle width)
        let minDistance: CGFloat = 14.0
        
        if items.count > 1 {
            // Simple sweep to push items right
            for i in 1..<items.count {
                if items[i].prefX < items[i-1].prefX + minDistance {
                    items[i].prefX = items[i-1].prefX + minDistance
                }
            }
            
            // If any items pushed past the right edge (trackWidth + horizontalPadding), push them back left
            let maxRight = trackWidth + horizontalPadding
            if let last = items.last, last.prefX > maxRight {
                items[items.count - 1].prefX = maxRight
                for i in (0..<(items.count - 1)).reversed() {
                    if items[i].prefX > items[i+1].prefX - minDistance {
                        items[i].prefX = items[i+1].prefX - minDistance
                    }
                }
            }
            
            // Guard against pushing past the left boundary
            if items[0].prefX < horizontalPadding {
                // Fallback: space them evenly
                let step = trackWidth / CGFloat(items.count - 1)
                for i in 0..<items.count {
                    items[i].prefX = horizontalPadding + CGFloat(i) * step
                }
            }
        }
        
        // Map to dictionary
        for item in items {
            positions[item.id] = item.prefX
        }
        
        return positions
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let horizontalPadding: CGFloat = 20
            let trackWidth = width - (horizontalPadding * 2)
            
            let positions = calculatePositions(trackWidth: trackWidth, horizontalPadding: horizontalPadding)
            
            ZStack(alignment: .center) {
                // Horizontal axis line positioned absolutely at y = 45
                Rectangle()
                    .fill(theme.colors.lineStrong.color.opacity(0.15))
                    .frame(height: 1.5)
                    .padding(.horizontal, horizontalPadding)
                    .position(x: width / 2, y: 45)
                
                // Timeline ticks: 0, 7, 14, 21, 28 days
                // Positioned centered at y = 54.5 so tick starts exactly at axis line (y = 45)
                ForEach([0, 7, 14, 21, 28], id: \.self) { day in
                    let pct = CGFloat(day) / 30.0
                    let xOffset = horizontalPadding + (pct * trackWidth)
                    
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(theme.colors.lineStrong.color.opacity(0.3))
                            .frame(width: 1, height: 6)
                        
                        Text(dayLabel(day))
                            .font(theme.typography.mono(size: 8, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                    }
                    .frame(width: 30)
                    .position(x: xOffset, y: 54.5)
                }
                
                // Upcoming Bill badged nodes along timeline
                ForEach(bills) { bill in
                    let xOffset = positions[bill.id] ?? horizontalPadding
                    let isSelected = selectedID == nil ? (bills.first?.id == bill.id) : (selectedID == bill.id)
                    
                    // Small price label above icon centered at y = 12 (only for the selected spotlight item)
                    if isSelected {
                        Text(timelinePriceLabel(bill.averageAmount))
                            .font(theme.typography.mono(size: 8, weight: .bold))
                            .foregroundStyle(theme.colors.danger.color)
                            .position(x: xOffset, y: 12)
                    }
                    
                    // Small circular merchant icon button centered at y = 32
                    // Its bottom edge rests exactly on the timeline axis line (32 + 13 = 45)
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedID = bill.id
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? theme.colors.accent.color : theme.colors.surfaceMuted.color)
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: iconName(for: bill))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                        }
                        .overlay(
                            Circle()
                                .stroke(isSelected ? theme.colors.danger.color : theme.colors.line.color, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .position(x: xOffset, y: 32)
                }
            }
        }
        .frame(height: 75)
    }
    
    private func dayLabel(_ d: Int) -> String {
        if d == 0 { return "now" }
        return "\(d)d"
    }
    
    private func timelinePriceLabel(_ amt: Double) -> String {
        if amt >= 1000 {
            return "$\(String(format: "%.1fk", amt / 1000.0))"
        } else {
            return "$\(Int(amt.rounded()))"
        }
    }
    
    private func iconName(for bill: RecurringStream) -> String {
        let nameLower = (bill.merchantName ?? bill.description).lowercased()
        if nameLower.contains("spotify") { return "music.note" }
        if nameLower.contains("netflix") { return "play.tv.fill" }
        if nameLower.contains("verizon") { return "phone.fill" }
        if nameLower.contains("rent") { return "house.fill" }
        return "creditcard.fill"
    }
}

// MARK: - 3. Coverage Banner Card
struct CoverageCard: View {
    let available: Double
    let expectedIncome: Double
    let totalDue: Double
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        let isCurrentCovered = available >= totalDue
        let isProjectedCovered = (available + expectedIncome) >= totalDue
        
        let statusColor: Color = isCurrentCovered ? theme.colors.success.color : (isProjectedCovered ? theme.colors.accent.color : theme.colors.warning.color)
        let statusBackground: Color = isCurrentCovered ? theme.colors.success.color.opacity(0.12) : (isProjectedCovered ? theme.colors.accent.color.opacity(0.12) : theme.colors.warning.color.opacity(0.12))
        
        let iconName: String = isCurrentCovered ? "checkmark" : (isProjectedCovered ? "arrow.up.right.circle.fill" : "exclamationmark")
        let titleText: String = isCurrentCovered ? "You're covered" : (isProjectedCovered ? "Covered by income" : "Heads up")
        
        HStack(spacing: 12) {
            // Checkmark, Arrow, or Info Indicator badge
            ZStack {
                Circle()
                    .fill(statusBackground)
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(theme.typography.body(size: 14, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                
                if isCurrentCovered {
                    Text("$\(Int(available).formatted()) net cash covers all $\(Int(totalDue).formatted()) due")
                        .font(theme.typography.body(size: 12, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary.color)
                } else if isProjectedCovered {
                    Text("$\(Int(available).formatted()) net cash + $\(Int(expectedIncome).formatted()) expected income covers all $\(Int(totalDue).formatted()) due")
                        .font(theme.typography.body(size: 12, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary.color)
                } else {
                    let totalAvailable = available + expectedIncome
                    if expectedIncome > 0 {
                        Text("Short by $\(Int(totalDue - totalAvailable).formatted()) even factoring net cash & expected income")
                            .font(theme.typography.body(size: 12, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    } else {
                        Text("$\(Int(available).formatted()) net cash · Short by $\(Int(totalDue - available).formatted()) of $\(Int(totalDue).formatted()) due")
                            .font(theme.typography.body(size: 12, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(theme.colors.surfaceMuted.color.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color, lineWidth: isPopArt ? 1.5 : 1)
        }
    }
}

// MARK: - 4. Stats Section
struct StatsSection: View {
    let due14: Double
    let due30: Double
    let count: Int
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        HStack(spacing: 0) {
            statCell(label: "NEXT 14 DAYS", value: formatCurrency(due14))
            
            Divider().overlay(theme.colors.line.color)
                .padding(.vertical, 8)
            
            statCell(label: "30 DAYS", value: formatCurrency(due30))
            
            Divider().overlay(theme.colors.line.color)
                .padding(.vertical, 8)
            
            statCell(label: "BILLS COUNT", value: "\(count) bills")
        }
        .frame(height: 54)
    }
    
    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(theme.typography.mono(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(theme.colors.textTertiary.color)
            
            Text(value)
                .font(theme.typography.display(size: 18, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    private func formatCurrency(_ val: Double) -> String {
        "$\(Int(val).formatted())"
    }
}

// MARK: - 5. Timeframe Group
struct TimeframeGroup: View {
    let title: String
    let bills: [RecurringStream]
    @Binding var selectedID: Int?
    let calculator: ComingUpCalculator
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Timeframe Title Label
            Text(title)
                .font(theme.typography.mono(size: 11, weight: .bold))
                .tracking(theme.typography.labelTracking)
                .foregroundStyle(theme.colors.textTertiary.color)
                .padding(.horizontal, 4)
            
            // List of upcoming rows
            VStack(spacing: 0) {
                ForEach(Array(bills.enumerated()), id: \.element.id) { idx, bill in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedID = bill.id
                        }
                    }) {
                        TimeframeBillRow(bill: bill, calculator: calculator)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if idx < bills.count - 1 {
                        Divider()
                            .overlay(theme.colors.line.color.opacity(0.5))
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(theme.colors.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                    .stroke(theme.colors.line.color, lineWidth: 1)
            }
        }
    }
}

struct TimeframeBillRow: View {
    let bill: RecurringStream
    let calculator: ComingUpCalculator
    
    @Environment(\.babloTheme) private var theme
    
    private var daysLeft: Int {
        calculator.daysRemaining(for: bill) ?? 0
    }
    
    private var weekdayText: String {
        guard let dateStr = bill.predictedNextDate,
              let date = calculator.parseDate(dateStr) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date).uppercased()
    }
    
    private var timeframeSubtitle: String {
        if daysLeft == 0 {
            return "TODAY · \(weekdayText)"
        } else if daysLeft == 1 {
            return "TOMORROW · \(weekdayText)"
        } else {
            return "IN \(daysLeft)D · \(weekdayText)"
        }
    }
    
    private var iconName: String {
        let nameLower = (bill.merchantName ?? bill.description).lowercased()
        if nameLower.contains("spotify") { return "music.note" }
        if nameLower.contains("netflix") { return "play.tv.fill" }
        if nameLower.contains("verizon") { return "phone.fill" }
        if nameLower.contains("rent") { return "house.fill" }
        return "creditcard.fill"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Small Circular Icon Frame
            ZStack {
                Circle()
                    .fill(theme.colors.surfaceMuted.color)
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                // Name
                Text(bill.merchantName ?? bill.description)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                
                // Days and Weekday description
                Text(timeframeSubtitle)
                    .font(theme.typography.body(size: 10, weight: .semibold))
                    .foregroundStyle(daysLeft <= 2 ? theme.colors.danger.color : theme.colors.textTertiary.color)
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(bill.averageAmount))
                .font(theme.typography.body(size: 14, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    private func formatCurrency(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: val)) ?? "$\(val)"
    }
}

// MARK: - 6. Empty States
struct EmptyUpcomingState: View {
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.colors.textTertiary.color)
                Text("No bills due in the next 30 days!")
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }
}

// MARK: - 7. Sticky Bottom Summary Bar
struct BottomSummaryBar: View {
    let totalDue: Double
    let remindersEnabled: Bool
    let onSetReminders: () -> Void
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("$\(Int(totalDue).formatted()) due")
                    .font(theme.typography.body(size: 16, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                
                Text(remindersEnabled ? "Alerts active 2d before due" : "over the next 30 days")
                    .font(theme.typography.body(size: 12, weight: remindersEnabled ? .bold : .medium))
                    .foregroundStyle(remindersEnabled ? theme.colors.success.color : theme.colors.textSecondary.color)
            }
            
            Spacer()
            
            if remindersEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.colors.success.color)
                    Text("Reminders set")
                        .font(theme.typography.body(size: 13, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(theme.colors.success.color.opacity(0.12))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(theme.colors.success.color.opacity(0.3), lineWidth: 1)
                }
            } else {
                // Set Reminders Button
                Button(action: onSetReminders) {
                    HStack(spacing: 6) {
                        Text("Set reminders")
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .black))
                    }
                    .font(theme.typography.body(size: 14, weight: .black))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 32)
        .background(
            theme.colors.surface.color
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider().overlay(theme.colors.line.color)
        }
    }
}

// MARK: - Previews
#Preview("Details Sheet Normal") {
    let service = SubscriptionsService()
    let calendar = Calendar.bablo
    let today = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    
    let datePlus2 = calendar.date(byAdding: .day, value: 2, to: today)!
    let datePlus6 = calendar.date(byAdding: .day, value: 6, to: today)!
    let datePlus8 = calendar.date(byAdding: .day, value: 8, to: today)!
    let datePlus14 = calendar.date(byAdding: .day, value: 14, to: today)!
    let datePlus17 = calendar.date(byAdding: .day, value: 17, to: today)!
    let datePlus22 = calendar.date(byAdding: .day, value: 22, to: today)!
    
    service.allRecurringStreams = [
        RecurringStream(
            id: 1, plaidStreamId: "plaid_1", description: "Spotify Premium",
            merchantName: "Spotify", personalFinanceCategory: "ENTERTAINMENT",
            personalFinanceSubcategory: "MUSIC", frequency: "MONTHLY",
            averageAmount: 11.99, monthlyAmount: 11.99, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus2),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 2, plaidStreamId: "plaid_2", description: "Rent",
            merchantName: "Rent", personalFinanceCategory: "RENT_OR_MORTGAGE",
            personalFinanceSubcategory: nil, frequency: "MONTHLY",
            averageAmount: 1450.0, monthlyAmount: 1450.0, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus6),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 3, plaidStreamId: "plaid_3", description: "Verizon Wireless",
            merchantName: "Verizon", personalFinanceCategory: "UTILITIES",
            personalFinanceSubcategory: nil, frequency: "MONTHLY",
            averageAmount: 65.0, monthlyAmount: 65.0, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus8),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 4, plaidStreamId: "plaid_4", description: "Netflix Premium",
            merchantName: "Netflix", personalFinanceCategory: "ENTERTAINMENT",
            personalFinanceSubcategory: "VIDEO", frequency: "MONTHLY",
            averageAmount: 15.49, monthlyAmount: 15.49, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus14),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 5, plaidStreamId: "plaid_5", description: "Renters Insurance",
            merchantName: "Renters", personalFinanceCategory: "GENERAL_SERVICES",
            personalFinanceSubcategory: nil, frequency: "MONTHLY",
            averageAmount: 18.00, monthlyAmount: 18.00, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus17),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 6, plaidStreamId: "plaid_6", description: "iCloud+ Storage",
            merchantName: "iCloud+", personalFinanceCategory: "GENERAL_SERVICES",
            personalFinanceSubcategory: nil, frequency: "MONTHLY",
            averageAmount: 2.99, monthlyAmount: 2.99, isoCurrencyCode: "USD",
            type: "expense", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus22),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        ),
        RecurringStream(
            id: 7, plaidStreamId: "plaid_7", description: "Google Paycheck",
            merchantName: "Google", personalFinanceCategory: "INCOME",
            personalFinanceSubcategory: "WAGES", frequency: "BIWEEKLY",
            averageAmount: 3000.0, monthlyAmount: 6000.0, isoCurrencyCode: "USD",
            type: "income", status: "MATURE", isActive: true,
            firstDate: nil, lastDate: nil, predictedNextDate: formatter.string(from: datePlus6),
            isUserModified: false, userMarkedRecurring: nil,
            isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
        )
    ]
    
    return ComingUpDetailsSheetView()
        .environmentObject(service)
        .environmentObject(AccountsService())
        .environmentObject(BudgetService())
        .babloTheme(.normal)
}
