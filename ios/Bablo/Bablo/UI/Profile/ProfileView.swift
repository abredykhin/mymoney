//
//  ProfileView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 11/2/24.
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @EnvironmentObject var userAccount: UserAccount
    @Environment(\.colorScheme) var colorScheme
    @State private var showingClearCacheAlert = false
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
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCoreDataCache()
            }
        } message: {
            Text("This will clear all locally stored data. Are you sure?")
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
        }
        .profileCardStyle()
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            ProfileActionRow(
                title: "Clear Cache Data",
                systemImage: "trash.circle",
                tint: ColorPalette.info,
                isDestructive: false,
                action: { showingClearCacheAlert = true }
            )

            Divider()

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
    
    private func clearCoreDataCache() {
        // We need to handle relationship constraints properly
        let context = CoreDataStack.shared.viewContext
        
        // Delete in the correct order to respect relationships
        // First clear transactions
        clearEntity(name: "TransactionEntity", in: context)
        
        // Then clear accounts
        clearEntity(name: "AccountEntity", in: context)
        
        // Finally clear banks
        clearEntity(name: "BankEntity", in: context)
        
        // Save changes
        do {
            try context.save()
            Logger.i("Cache clearing completed successfully")
        } catch {
            Logger.e("Failed to save context after clearing cache: \(error.localizedDescription)")
        }
    }
    
    private func clearEntity(name entityName: String, in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        
        do {
            // Fetch all objects instead of using batch delete to properly handle relationships
            let objects = try context.fetch(fetchRequest)
            
            // Delete each object individually to respect relationship cascade rules
            for object in objects {
                if let managedObject = object as? NSManagedObject {
                    context.delete(managedObject)
                }
            }
            
            Logger.i("Successfully cleared \(entityName) entities")
        } catch {
            Logger.e("Failed to clear \(entityName) entities: \(error.localizedDescription)")
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
