//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    @Environment(\.colorScheme) var colorScheme
    @State private var settingsError: String?
    
    var body: some View {
        ZStack {
            ColorPalette.backgroundSecondary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let name = userAccount.currentUser?.name {
                        VStack(spacing: Spacing.sm) {
                            Text("Hello,")
                                .font(Typography.bodySemibold)
                                .foregroundColor(ColorPalette.textSecondary)

                            Text(name)
                                .font(Typography.h2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxl)
                        .background(ColorPalette.backgroundPrimary)
                    }

                    settingsCard
                    accountCard
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .alert("Settings Error", isPresented: Binding(
            get: { settingsError != nil },
            set: { if !$0 { settingsError = nil } }
        )) {
            Button("OK", role: .cancel) { settingsError = nil }
        } message: {
            Text(settingsError ?? "")
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Settings", systemImage: "gearshape")
                .font(Typography.bodySemibold)
                .foregroundColor(ColorPalette.textPrimary)

            Picker("Spending Plan", selection: Binding(
                get: { userAccount.spendingPlanMode },
                set: { newMode in
                    Task {
                        await saveSpendingPlanMode(newMode)
                    }
                }
            )) {
                ForEach(SpendingPlanMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, Spacing.xs)

            Text("Income Basis")
                .font(Typography.bodySemibold)
                .foregroundColor(ColorPalette.textPrimary)

            Picker("Income Basis", selection: Binding(
                get: { userAccount.incomeBasis },
                set: { newBasis in
                    Task {
                        try? await userAccount.updateIncomeBasis(newBasis)
                    }
                }
            )) {
                ForEach(IncomeBasis.allCases, id: \.self) { basis in
                    Text(basis.displayName).tag(basis)
                }
            }
            .pickerStyle(.segmented)
        }
        .profileCardStyle()
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            ProfileActionRow(
                title: "Sign Out",
                systemImage: "arrow.right.circle",
                tint: ColorPalette.error,
                isDestructive: true,
                action: handleSignOut
            )
        }
        .profileCardStyle()
    }

    private func saveSpendingPlanMode(_ mode: SpendingPlanMode) async {
        do {
            try await userAccount.updateSpendingPlanMode(mode)
        } catch {
            settingsError = error.localizedDescription
        }
    }
    
    private func handleSignOut() {
        userAccount.signOut()
    }
}

private struct ProfileActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Typography.body)
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(tint)
            }
            .foregroundColor(isDestructive ? ColorPalette.error : ColorPalette.textPrimary)
            .padding(.vertical, Spacing.md)
        }
    }
}

private extension View {
    func profileCardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorPalette.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}
