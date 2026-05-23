import SwiftUI

struct OnboardingIncomeView: View {
    @Bindable var vm: IncomeInputViewModel
    let userName: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("HEY \(userName.uppercased())")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(theme.typography.labelTracking)
                    .foregroundStyle(theme.colors.textSecondary.color)

                Text("What's coming in?")
                    .font(theme.typography.title(size: 34, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text("Roughly what hits your account each month, after taxes.")
                    .font(theme.typography.body(size: 15))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 28)

            Spacer()

            // Amount display
            VStack(spacing: 6) {
                Text("PER MONTH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(theme.typography.labelTracking)
                    .foregroundStyle(theme.colors.textTertiary.color)

                Text(vm.displayAmount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: vm.displayAmount)
            }

            Spacer()

            // Numpad
            OnboardingNumPad { key in vm.handleKey(key) }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.bottom, 20)

            // CTA
            OnboardingCTAButton(label: "Looks right", action: onContinue)
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.bottom, 12)
        }
    }
}

#Preview {
    let vm = IncomeInputViewModel()
    return OnboardingIncomeView(
        vm: vm,
        userName: "Sam",
        onContinue: {},
        onSkip: {}
    )
    .background(Color(hex: "#F8F5EF"))
}
