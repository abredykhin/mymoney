import SwiftUI

struct HeroBudgetEmptyStateView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Monthly Budget")
                    .font(Typography.buttonLabel)
                    .foregroundColor(ColorPalette.textSecondary)
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(ColorPalette.categoryLoanPayments) // Using purple equivalent
            }
            
            Text("Set up your budget to unlock insights")
                .font(Typography.h3)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("Get Started")
                    .font(Typography.bodySemibold)
                Image(systemName: "arrow.right")
                    .font(Typography.footnote)
            }
            .foregroundColor(ColorPalette.info)
        }
        .glassCard()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        HeroBudgetEmptyStateView()
            .environmentObject(NavigationState())
    }
}
