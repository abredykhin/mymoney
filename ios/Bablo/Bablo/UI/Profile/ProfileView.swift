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
    
    var body: some View {
        ZStack {
            ColorPalette.backgroundSecondary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                
                List {
                    Section {
                        Button(action: {
                            showingClearCacheAlert = true
                        }) {
                            HStack {
                                Text("Clear Cache Data")
                                    .font(Typography.body)
                                Spacer()
                                Image(systemName: "trash.circle")
                                    .foregroundColor(ColorPalette.info)
                            }
                            .foregroundColor(ColorPalette.textPrimary)
                        }
                        
                        Button(action: handleSignOut) {
                            HStack {
                                Text("Sign Out")
                                    .font(Typography.body)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(ColorPalette.error)
                            }
                            .foregroundColor(ColorPalette.error)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive) {
                        clearCoreDataCache()
                    }
                } message: {
                    Text("This will clear all locally stored data. Are you sure?")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
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
