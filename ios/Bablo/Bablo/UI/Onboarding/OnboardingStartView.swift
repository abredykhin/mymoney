import SwiftUI

struct OnboardingStartView: View {
    var body: some View {
        ZStack {
            // Expansive Background Glow
            // Expansive Background Glow
            Circle()
                .fill(ColorPalette.glowPositive.opacity(0.4))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: -150, y: -100)
                .allowsHitTesting(false)
            
            Circle()
                .fill(ColorPalette.info.opacity(0.3)) // Blue glow
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: 200, y: 100)
                .allowsHitTesting(false)

            VStack(spacing: Spacing.xl) {
                Spacer()
                
                // Glassmorphic Graphic (Central Illustration)
                ZStack {
                    // Main Glass Card
                    RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 200, height: 130)
                        .overlay {
                            RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous)
                                .stroke(ColorPalette.glassStroke, lineWidth: 1)
                        }
                        .shadow(Elevation.glowPositive) // Close match or use custom
                    
                    // Card Details (Simulated)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 20, height: 20)
                        
                        HStack(spacing: Spacing.xs) {
                            ForEach(0..<4) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 25, height: 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(Spacing.lg)
                    .frame(width: 200, height: 130, alignment: .topLeading)
                    
                    // Floating Icons
                    Image(systemName: "dollarsign.circle.fill")
                        .font(Typography.displaySmall)
                        .foregroundStyle(LinearGradient(colors: [ColorPalette.success.opacity(0.6), ColorPalette.primary.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: -70, y: -50)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(Typography.h1)
                        .foregroundStyle(LinearGradient(colors: [ColorPalette.info.opacity(0.5), ColorPalette.categoryLoanPayments.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: 80, y: -30)
                    
                    Image(systemName: "shield.fill")
                        .font(Typography.displayMedium)
                        .foregroundStyle(LinearGradient(colors: [ColorPalette.info.opacity(0.7), ColorPalette.categoryTravel.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: 60, y: 50)
                        .shadow(color: ColorPalette.info.opacity(0.2), radius: 10, x: 5, y: 5)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(Typography.displaySmall)
                        .foregroundStyle(LinearGradient(colors: [ColorPalette.primary.opacity(0.5), ColorPalette.success.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .offset(x: -80, y: 40)
                }
                .padding(.top, Spacing.xl)
                
                VStack(spacing: Spacing.md) {
                    Text("Master your money, effortlessly.")
                        .font(Typography.h2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ColorPalette.textPrimary)
                        .padding(.horizontal, Spacing.xl)
                        .minimumScaleFactor(0.8)
                    
                    Text("Track net worth, manage spending, and unlock your true discretionary budget.")
                        .font(Typography.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.horizontal, Spacing.xxl)
                }
                
                Spacer()
            }
            .padding(.bottom, 60) // Keep footer spacing
        }
    }
}

#Preview {
    OnboardingStartView()
}
