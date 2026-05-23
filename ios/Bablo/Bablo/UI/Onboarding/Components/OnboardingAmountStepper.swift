import SwiftUI

/// Inline $ amount field with up/down stepper arrows.
struct OnboardingAmountStepper: View {
    @Binding var amount: Int
    var step: Int = 10

    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            Text("$")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
                .padding(.leading, 10)

            TextField("", value: $amount, format: .number)
                .keyboardType(.numberPad)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary.color)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)

            VStack(spacing: 0) {
                Button { amount += step } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                Button { amount = max(0, amount - step) } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 28, height: 38)
            .background(theme.colors.surfaceMuted.color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.leading, 6)
            .padding(.trailing, 4)
        }
        .frame(height: 38)
        .background(theme.colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
        )
    }
}
