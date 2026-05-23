import SwiftUI

struct OnboardingNameView: View {
    @Bindable var vm: OnboardingNameInputViewModel
    let isSaving: Bool
    let onContinue: () -> Void

    @FocusState private var isNameFocused: Bool
    @Environment(\.babloTheme) private var theme

    private let quickNames = ["Mia", "Jordan", "Sam", "Riley"]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("QUICK START")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(theme.typography.labelTracking)
                        .foregroundStyle(theme.colors.textSecondary.color)

                    Spacer()

                    Text("HI!")
                        .font(.system(size: 28, weight: .bold, design: .rounded).italic())
                        .foregroundStyle(theme.colors.textTertiary.color.opacity(0.5))
                        .rotationEffect(.degrees(7))
                }

                Text("What should we call you?")
                    .font(theme.typography.title(size: 34, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .minimumScaleFactor(0.82)

                Text("Just a first name. We'll keep it casual.")
                    .font(theme.typography.body(size: 17))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 28)

            TextField("Mia", text: $vm.firstName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.colors.textPrimary.color)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .padding(.horizontal, 22)
                .frame(height: 78)
                .background(theme.colors.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                        .stroke(
                            isNameFocused ? theme.colors.accent.color : theme.colors.line.color,
                            lineWidth: isNameFocused ? 3 : theme.metrics.borderWidth
                        )
                }
                .padding(.horizontal, theme.metrics.screenPadding)
                .padding(.top, 24)

            HStack(alignment: .center, spacing: 10) {
                Text("quick:")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary.color)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickNames, id: \.self) { name in
                            Button {
                                vm.chooseQuickName(name)
                                isNameFocused = false
                            } label: {
                                Text(name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(theme.colors.textPrimary.color)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.horizontal, 22)
                                    .frame(minWidth: quickChipMinWidth(for: name), minHeight: 50)
                                    .background(theme.colors.surface.color)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.top, 18)

            Spacer()

            OnboardingCTAButton(
                label: "Next",
                isLoading: isSaving,
                isDisabled: !vm.canContinue,
                action: onContinue
            )
            .padding(.horizontal, theme.metrics.screenPadding)
            .padding(.bottom, 12)
        }
        .onAppear {
            isNameFocused = true
        }
    }

    private func quickChipMinWidth(for name: String) -> CGFloat {
        switch name.count {
        case 0...3: 74
        case 4...5: 88
        default: 112
        }
    }
}

#Preview("Name - Empty") {
    OnboardingNameView(
        vm: OnboardingNameInputViewModel(),
        isSaving: false,
        onContinue: {}
    )
    .background(Color(hex: "#F8F5EF"))
}

#Preview("Name - Filled") {
    let vm = OnboardingNameInputViewModel()
    vm.firstName = "Mia"
    return OnboardingNameView(
        vm: vm,
        isSaving: false,
        onContinue: {}
    )
    .background(Color(hex: "#F8F5EF"))
}
