import SwiftUI

struct OnboardingBudgetView: View {
    @Binding var income: String
    @Binding var expenses: String
    
    var discretionary: Double {
        let inc = Double(income) ?? 0
        let exp = Double(expenses) ?? 0
        return max(0, inc - exp)
    }
    
    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(ColorPalette.glowIncome.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(y: 100)
            
            VStack(spacing: Spacing.xl) {
                Text("Let's define your\n\"Fun Money\".")
                    .font(Typography.h1)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xxxl)
                
                // Input Card
                VStack(spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Monthly Income")
                            .font(Typography.captionBold)
                        
                        TextField("Amount", text: $income)
                            .keyboardType(.decimalPad)
                            .font(Typography.h4)
                            .padding(Spacing.lg)
                            .background {
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(ColorPalette.success.opacity(0.5), lineWidth: 2)
                                    .shadow(color: ColorPalette.success.opacity(0.3), radius: 8)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Mandatory Expenses (rent, bills, etc.)")
                            .font(Typography.captionBold)
                        
                        TextField("Amount", text: $expenses)
                            .keyboardType(.decimalPad)
                            .font(Typography.h4)
                            .padding(Spacing.lg)
                            .background {
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(ColorPalette.warning.opacity(0.5), lineWidth: 2)
                                    .shadow(color: ColorPalette.warning.opacity(0.3), radius: 8)
                            }
                    }
                    
                    VStack(spacing: Spacing.xs) {
                        Text(discretionary, format: .currency(code: "USD"))
                            .font(Typography.displayMedium)
                        
                        Text("Discretionary Budget")
                            .font(Typography.h4)
                        
                        Text("This is your flexible \"fun money\" for the month.")
                            .font(Typography.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.sm)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.xl)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                        .fill(ColorPalette.backgroundPrimary)
                        .shadow(Elevation.level4)
                }
                .padding(.horizontal, Spacing.xl)
                
                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingBudgetView(income: .constant("5500"), expenses: .constant("4300"))
}
