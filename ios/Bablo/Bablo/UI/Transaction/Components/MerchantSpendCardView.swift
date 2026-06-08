import SwiftUI

struct MerchantSpendCardView: View {
    @Environment(\.babloTheme) private var theme
    @State private var selectedBarIndex: Int = 11

    let provider: MerchantWeeklyDataProvider
    let merchantShortName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            barChart
            axisLabels
        }
        .padding(16)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOU & \(merchantShortName.uppercased())")
                    .font(theme.typography.mono(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(theme.colors.textSecondary.color)
                Text(summaryText)
                    .font(theme.typography.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            Spacer()
            Text(selectedWeekAmountText)
                .font(theme.typography.body(size: 18, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
        }
    }

    private var barChart: some View {
        ZStack {
            GeometryReader { geometry in
                let bars = provider.normalizedBars
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == selectedBarIndex
                                  ? theme.colors.accent.color
                                  : theme.colors.accent.color.opacity(0.35))
                            .opacity(value > 0 ? 1 : 0)
                            .frame(height: value > 0 ? 14 + CGFloat(value) * 58 : 0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if value > 0 { selectedBarIndex = index }
                            }
                    }
                }
                .frame(height: 80, alignment: .bottom)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard geometry.size.width > 0 else { return }
                            let bars = provider.normalizedBars
                            let pct = drag.location.x / geometry.size.width
                            let index = max(0, min(bars.count - 1, Int(pct * CGFloat(bars.count))))
                            if provider.weeklyData[index].totalSpent > 0 {
                                selectedBarIndex = index
                            }
                        }
                )
            }

            if !provider.hasPriorSpend {
                Text("First time in 12 weeks")
                    .font(theme.typography.body(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.colors.surfaceMuted.color.opacity(0.7))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 80)
    }

    private var axisLabels: some View {
        HStack {
            Text("12 weeks ago")
            Spacer()
            Text("this week")
        }
        .font(theme.typography.body(size: 12, weight: .semibold))
        .foregroundStyle(theme.colors.textSecondary.color)
    }

    private var selectedWeekData: MerchantWeeklySpendData? {
        let data = provider.weeklyData
        guard selectedBarIndex >= 0 && selectedBarIndex < data.count else { return nil }
        return data[selectedBarIndex]
    }

    private var summaryText: String {
        guard let weekData = selectedWeekData else { return "No spend" }
        let label = provider.weekLabel(for: weekData)
        guard weekData.transactionCount > 0 else { return "No spend \(label)" }
        return "\(weekData.transactionCount)x spend \(label)"
    }

    private var selectedWeekAmountText: String {
        guard let weekData = selectedWeekData else { return "$0" }
        return NumberFormatter.currency.string(from: NSNumber(value: weekData.totalSpent))
            ?? "$\(Int(weekData.totalSpent.rounded()))"
    }
}

#Preview {
    let mockTx = Transaction(
        id: 1,
        account_id: 10,
        amount: 25.50,
        date: "2026-06-05",
        authorized_date: "2026-06-05",
        name: "Blue Bottle Coffee",
        merchant_name: "Blue Bottle",
        pending: false,
        category: nil,
        transaction_id: "preview_tx_1",
        pending_transaction_transaction_id: nil,
        iso_currency_code: "USD",
        payment_channel: "in store",
        user_id: nil,
        logo_url: nil,
        website: nil,
        personal_finance_category: "FOOD_AND_DRINK",
        personal_finance_subcategory: "FOOD_AND_DRINK_COFFEE",
        created_at: nil,
        updated_at: nil,
        is_spend: true,
        is_income: false
    )
    let provider = MerchantWeeklyDataProvider(transactions: [mockTx], currentTransaction: mockTx)
    return MerchantSpendCardView(provider: provider, merchantShortName: "Blue Bottle")
        .padding()
}

