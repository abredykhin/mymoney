//
//  SubsWidgetView.swift
//  Bablo
//

import SwiftUI

struct SubsWidgetView: View {
    @EnvironmentObject var subService: SubscriptionsService
    @EnvironmentObject var transactionsService: TransactionsService
    @Environment(\.babloTheme) private var theme
    @State private var isShowingDetail = false

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
        .contentShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .onTapGesture {
            isShowingDetail = true
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows subscription details")
        .sheet(isPresented: $isShowingDetail) {
            SubsDetailSheetView()
                .environmentObject(subService)
                .environmentObject(transactionsService)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
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

// MARK: - Detail Summary

struct SubsDetailCategoryBreakdown: Identifiable, Equatable {
    let title: String
    let amount: Double

    var id: String { title }
}

struct SubsDetailSummary: Equatable {
    let streams: [RecurringStream]
    let idleSubscriptionIDs: Set<Int>
    let fallbackIdleCount: Int

    var totalMonthlyCost: Double {
        streams.reduce(0) { $0 + $1.monthlyAmount }
    }

    var annualCost: Double {
        totalMonthlyCost * 12
    }

    var idleCount: Int {
        if !idleSubscriptionIDs.isEmpty {
            return idleSubscriptionIDs.count
        }
        return min(fallbackIdleCount, streams.count)
    }

    var activeCount: Int {
        max(streams.count - idleCount, 0)
    }

    var idleMonthlyCost: Double {
        idleStreams.reduce(0) { $0 + $1.monthlyAmount }
    }

    var idleAnnualCost: Double {
        idleMonthlyCost * 12
    }

    var sortedStreams: [RecurringStream] {
        streams.sorted { lhs, rhs in
            let lhsIdle = isIdle(lhs)
            let rhsIdle = isIdle(rhs)
            if lhsIdle != rhsIdle { return lhsIdle && !rhsIdle }
            return lhs.monthlyAmount > rhs.monthlyAmount
        }
    }

    var categoryBreakdowns: [SubsDetailCategoryBreakdown] {
        let grouped = Dictionary(grouping: streams, by: Self.categoryTitle(for:))
        return grouped
            .map { title, streams in
                SubsDetailCategoryBreakdown(
                    title: title,
                    amount: streams.reduce(0) { $0 + $1.monthlyAmount }
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    func isIdle(_ stream: RecurringStream) -> Bool {
        idleSubscriptionIDs.contains(stream.id)
    }

    private var idleStreams: [RecurringStream] {
        if !idleSubscriptionIDs.isEmpty {
            return streams.filter(isIdle)
        }

        guard fallbackIdleCount > 0 else { return [] }
        return Array(
            streams
                .sorted { $0.monthlyAmount > $1.monthlyAmount }
                .prefix(fallbackIdleCount)
        )
    }

    static func categoryTitle(for stream: RecurringStream) -> String {
        let category = stream.personalFinanceCategory?.uppercased() ?? ""
        let subcategory = stream.personalFinanceSubcategory?.uppercased() ?? ""

        if subcategory.contains("MUSIC") { return "Music" }
        if subcategory.contains("VIDEO") || subcategory.contains("TV") || subcategory.contains("STREAM") { return "Video" }
        if subcategory.contains("CLOUD") || subcategory.contains("STORAGE") { return "Cloud" }
        if subcategory.contains("CREATIVE") || category.contains("GENERAL_SERVICES") { return "Work" }
        if category.contains("ENTERTAINMENT") { return "Video" }
        if category.contains("UTILITIES") { return "Utility" }
        if category.contains("FOOD") { return "Food" }
        if category.contains("RENT") || category.contains("HOME") { return "Home" }
        if let subcategory = stream.personalFinanceSubcategory, !subcategory.isEmpty {
            return friendlyLabel(subcategory)
        }
        if let category = stream.personalFinanceCategory, !category.isEmpty {
            return friendlyLabel(category)
        }
        return "Other"
    }

    private static func friendlyLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .split(separator: " ")
            .prefix(2)
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

struct SubsStreamRowMetadata: Equatable {
    let stream: RecurringStream
    let isIdle: Bool
    let currentDate: Date

    init(stream: RecurringStream, isIdle: Bool, currentDate: Date = Date()) {
        self.stream = stream
        self.isIdle = isIdle
        self.currentDate = currentDate
    }

    var statusText: String {
        guard !isIdle else {
            return "IDLE"
        }

        guard let lastDate = parsedDate(stream.lastDate) else {
            return "ACTIVE"
        }

        let calendar = Calendar.bablo
        if calendar.isDate(lastDate, inSameDayAs: currentDate) {
            return "CHARGED TODAY"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate),
           calendar.isDate(lastDate, inSameDayAs: yesterday) {
            return "CHARGED YESTERDAY"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "CHARGED \(formatter.string(from: lastDate).uppercased())"
    }

    private func parsedDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        return parser.date(from: raw)
    }
}

// MARK: - Subs Detail Sheet

struct SubsDetailSheetView: View {
    @EnvironmentObject private var subService: SubscriptionsService
    @EnvironmentObject private var transactionsService: TransactionsService
    @Environment(\.babloTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var summary: SubsDetailSummary {
        SubsDetailSummary(
            streams: subService.subscriptions,
            idleSubscriptionIDs: subService.idleSubscriptionIDs,
            fallbackIdleCount: subService.idleCount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            handle

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if summary.streams.isEmpty {
                        emptyState
                    } else {
                        categorySection
                        idleNudge
                        statsRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                if !summary.streams.isEmpty {
                    subscriptionList
                }
            }

            if !summary.streams.isEmpty {
                bottomBar
            }
        }
        .background(theme.colors.surface.color.ignoresSafeArea())
    }

    private var handle: some View {
        Capsule()
            .fill(theme.colors.lineStrong.color.opacity(0.55))
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUBSCRIPTIONS")
                        .font(theme.typography.mono(size: 12, weight: .bold))
                        .tracking(theme.typography.labelTracking)
                        .foregroundStyle(theme.colors.textTertiary.color)

                    Text("Your recurring drip")
                        .font(theme.typography.title(size: 30, weight: theme.effects.isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text("\(summary.streams.count) subs · auto-charged each month")
                        .font(theme.typography.body(size: 17, weight: .medium))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .padding(.top, 2)
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .frame(width: 54, height: 54)
                        .background(theme.colors.surfaceMuted.color)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close subscriptions")
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(summary.totalMonthlyCost))
                    .font(theme.typography.display(size: 58, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text("/mo")
                    .font(theme.typography.body(size: 25, weight: .black))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Text("\(formatCurrency(summary.annualCost, maximumFractionDigits: 0)) a year")
                .font(theme.typography.body(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary.color)
                .offset(y: -12)
                .padding(.bottom, -8)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubsCategorySpendBar(categories: summary.categoryBreakdowns)

            FlowLayout(spacing: 10, lineSpacing: 8) {
                ForEach(summary.categoryBreakdowns) { category in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(color(for: category.title))
                            .frame(width: 9, height: 9)
                        Text(category.title)
                            .font(theme.typography.body(size: 14, weight: .bold))
                            .foregroundStyle(theme.colors.textSecondary.color)
                        Text(formatCurrency(category.amount, maximumFractionDigits: 0))
                            .font(theme.typography.body(size: 14, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var idleNudge: some View {
        if summary.idleCount > 0 {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.colors.accentDeep.color)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(theme.colors.accent.color)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Drop \(summary.idleCount) idle subs, save \(formatCurrency(summary.idleMonthlyCost, maximumFractionDigits: 0))/mo")
                        .font(theme.typography.title(size: 20, weight: theme.effects.isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.accentDeep.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("That's \(formatCurrency(summary.idleAnnualCost, maximumFractionDigits: 0)) a year back in your pocket")
                        .font(theme.typography.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(theme.colors.accent.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(theme.colors.accent.color.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "ACTIVE", value: "\(summary.activeCount)", valueColor: theme.colors.textPrimary.color)
            Divider().overlay(theme.colors.line.color)
            statCell(label: "IDLE", value: "\(summary.idleCount)", valueColor: theme.colors.danger.color)
            Divider().overlay(theme.colors.line.color)
            statCell(label: "PER YEAR", value: formatCurrency(summary.annualCost, maximumFractionDigits: 0), valueColor: theme.colors.textPrimary.color)
        }
        .frame(height: 68)
    }

    private func statCell(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(theme.typography.mono(size: 12, weight: .bold))
                .tracking(theme.typography.labelTracking)
                .foregroundStyle(theme.colors.textTertiary.color)
            Text(value)
                .font(theme.typography.display(size: 28, weight: .black))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subscriptionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(summary.sortedStreams) { stream in
                let isIdle = summary.isIdle(stream)
                SubsDetailRow(
                    stream: stream,
                    isIdle: isIdle,
                    logoUrl: logoUrl(for: stream)
                )
                .background(isIdle ? theme.colors.danger.color.opacity(0.045) : theme.colors.surface.color)

                if stream.id != summary.sortedStreams.last?.id {
                    Divider()
                        .overlay(theme.colors.line.color)
                }
            }
        }
        .background(theme.colors.surface.color)
        .overlay(alignment: .top) {
            Divider().overlay(theme.colors.line.color)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary.color)
            Text("No subscriptions spotted yet")
                .font(theme.typography.title(size: 22, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
            Text("Once Plaid finds recurring card charges, they'll show up here.")
                .font(theme.typography.body(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surfaceMuted.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatCurrency(summary.totalMonthlyCost))/mo")
                    .font(theme.typography.body(size: 17, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                Text("across \(summary.streams.count) subscriptions")
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            Spacer()

            Button {
                // Placeholder for the future cancellation/review workflow.
            } label: {
                HStack(spacing: 7) {
                    Text("Review idle")
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .black))
                }
                .font(theme.typography.body(size: 15, weight: .black))
                .foregroundStyle(theme.colors.surface.color)
                .padding(.horizontal, 22)
                .frame(height: 48)
                .background(theme.colors.textPrimary.color)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(summary.idleCount == 0)
            .opacity(summary.idleCount == 0 ? 0.45 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(theme.colors.line.color)
        }
    }

    private func logoUrl(for stream: RecurringStream) -> String? {
        SubscriptionLogoResolver.logoUrl(
            for: stream,
            transactions: transactionsService.transactions
        )
    }

    private func color(for category: String) -> Color {
        switch category {
        case "Work": return Color(hex: "#7160D8") ?? .indigo
        case "Video": return theme.colors.danger.color
        case "Music": return Color(hex: "#52C55A") ?? theme.colors.success.color
        case "Cloud": return theme.colors.info.color
        case "Utility": return theme.colors.warning.color
        case "Food": return Color(hex: "#E15196") ?? theme.colors.avatarPink.color
        default: return theme.colors.textTertiary.color
        }
    }

    private func formatCurrency(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        SubsCurrencyFormatter.string(from: value, maximumFractionDigits: maximumFractionDigits)
    }
}

private struct SubsCategorySpendBar: View {
    let categories: [SubsDetailCategoryBreakdown]

    @Environment(\.babloTheme) private var theme

    private var total: Double {
        categories.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(categories) { category in
                    RoundedRectangle(cornerRadius: 0)
                        .fill(color(for: category.title))
                        .frame(width: segmentWidth(for: category, totalWidth: geometry.size.width))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 20)
    }

    private func segmentWidth(for category: SubsDetailCategoryBreakdown, totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return max(8, totalWidth * CGFloat(category.amount / total))
    }

    private func color(for category: String) -> Color {
        switch category {
        case "Work": return Color(hex: "#7160D8") ?? .indigo
        case "Video": return theme.colors.danger.color
        case "Music": return Color(hex: "#52C55A") ?? theme.colors.success.color
        case "Cloud": return theme.colors.info.color
        case "Utility": return theme.colors.warning.color
        case "Food": return Color(hex: "#E15196") ?? theme.colors.avatarPink.color
        default: return theme.colors.textTertiary.color
        }
    }
}

private struct SubsDetailRow: View {
    let stream: RecurringStream
    let isIdle: Bool
    let logoUrl: String?

    @Environment(\.babloTheme) private var theme

    private var displayName: String {
        stream.merchantName ?? stream.description
    }

    var body: some View {
        HStack(spacing: 14) {
            SubsMerchantIcon(name: displayName, logoUrl: logoUrl)

            VStack(alignment: .leading, spacing: 7) {
                Text(displayName)
                    .font(theme.typography.body(size: 18, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    BabloBadge(
                        title: statusText,
                        tone: isIdle ? .custom(theme.colors.danger.color.opacity(0.14), theme.colors.danger.color) : .accent
                    )

                    Text(renewalText)
                        .font(theme.typography.body(size: 14, weight: .medium))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(theme.typography.mono(size: 18, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                if isIdle {
                    Button("Cancel") {}
                        .font(theme.typography.body(size: 14, weight: .black))
                        .foregroundStyle(theme.colors.danger.color)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(theme.colors.surface.color)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(theme.colors.danger.color.opacity(0.8), lineWidth: 1)
                        }
                        .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var statusText: String {
        SubsStreamRowMetadata(stream: stream, isIdle: isIdle).statusText
    }

    private var renewalText: String {
        guard let nextDate = parsedDate(stream.predictedNextDate) else {
            return stream.frequencyDisplay
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return "Renews \(formatter.string(from: nextDate))"
    }

    private var amountText: String {
        SubsCurrencyFormatter.string(from: stream.averageAmount, maximumFractionDigits: 2)
    }

    private func parsedDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        return parser.date(from: raw)
    }
}

private struct SubsMerchantIcon: View {
    let name: String
    let logoUrl: String?

    @Environment(\.babloTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(brandColor(for: name))

            if let logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                } placeholder: {
                    initial
                }
            } else {
                initial
            }
        }
        .frame(width: 58, height: 58)
    }

    private var initial: some View {
        Text(name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "S")
            .font(theme.typography.body(size: 24, weight: .black))
            .foregroundStyle(.white)
    }

    private func brandColor(for name: String) -> Color {
        let nameLower = name.lowercased()
        if nameLower.contains("spotify") { return Color(hex: "#1DB954") ?? .green }
        if nameLower.contains("netflix") { return theme.colors.danger.color }
        if nameLower.contains("cursor") { return Color(hex: "#8A7A65") ?? .brown }
        if nameLower.contains("icloud") || nameLower.contains("apple") { return theme.colors.info.color }
        if nameLower.contains("notion") { return Color(hex: "#4D463D") ?? .gray }
        if nameLower.contains("figma") { return Color(hex: "#E15196") ?? theme.colors.avatarPink.color }
        return CircleAvatarBrandColor.color(for: name)
    }
}

private enum SubscriptionLogoResolver {
    static func logoUrl(for stream: RecurringStream, transactions: [Transaction]) -> String? {
        if let merchant = stream.merchantName,
           let match = transactions.first(where: { ($0.merchantName ?? "").localizedCaseInsensitiveContains(merchant) }),
           let url = match.logoUrl {
            return url
        }

        if let match = transactions.first(where: { $0.name.localizedCaseInsensitiveContains(stream.description) }),
           let url = match.logoUrl {
            return url
        }

        return nil
    }
}

private enum CircleAvatarBrandColor {
    static func color(for name: String) -> Color {
        let colors: [Color] = [
            .pink, .purple, .indigo, .blue, .cyan, .teal, .orange, .red, .gray
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

private enum SubsCurrencyFormatter {
    static func string(from value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = maximumFractionDigits == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(for: subviews, maxWidth: maxWidth)
        return CGSize(
            width: maxWidth,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        for row in rows(for: subviews, maxWidth: bounds.width) {
            origin.x = bounds.minX
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: origin.x, y: origin.y),
                    proposal: ProposedViewSize(element.size)
                )
                origin.x += element.size.width + spacing
            }
            origin.y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width + size.width + (current.elements.isEmpty ? 0 : spacing) > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.add(subview: subview, size: size, spacing: spacing)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        var elements: [(subview: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func add(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !elements.isEmpty {
                width += spacing
            }
            elements.append((subview, size))
            width += size.width
            height = max(height, size.height)
        }
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
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
                ),
                RecurringStream(
                    id: 2, plaidStreamId: "plaid_2", description: "Netflix Standard",
                    merchantName: "Netflix", personalFinanceCategory: "ENTERTAINMENT",
                    personalFinanceSubcategory: "VIDEO", frequency: "MONTHLY",
                    averageAmount: 12.99, monthlyAmount: 12.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
                ),
                RecurringStream(
                    id: 3, plaidStreamId: "plaid_3", description: "Canva Pro",
                    merchantName: "Canva", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CREATIVE", frequency: "MONTHLY",
                    averageAmount: 12.85, monthlyAmount: 12.85, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
                ),
                RecurringStream(
                    id: 4, plaidStreamId: "plaid_4", description: "Figma Team",
                    merchantName: "Figma", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "DESIGN", frequency: "MONTHLY",
                    averageAmount: 10.00, monthlyAmount: 10.00, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
                ),
                RecurringStream(
                    id: 5, plaidStreamId: "plaid_5", description: "Adobe CC",
                    merchantName: "Adobe", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CREATIVE", frequency: "MONTHLY",
                    averageAmount: 54.99, monthlyAmount: 54.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
                ),
                RecurringStream(
                    id: 6, plaidStreamId: "plaid_6", description: "Google One",
                    merchantName: "Google", personalFinanceCategory: "GENERAL_SERVICES",
                    personalFinanceSubcategory: "CLOUD", frequency: "MONTHLY",
                    averageAmount: 1.99, monthlyAmount: 1.99, isoCurrencyCode: "USD",
                    type: "expense", status: "MATURE", isActive: true,
                    firstDate: nil, lastDate: nil, predictedNextDate: nil,
                    isUserModified: false, userMarkedRecurring: nil,
                    isExcluded: false, isManual: false, matchPattern: nil, accountId: nil
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
