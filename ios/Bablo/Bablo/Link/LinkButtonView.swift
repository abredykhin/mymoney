    //
    //  LinkButtonView.swift
    //  mymoney
    //
    //  Created by Anton Bredykhin on 2/20/24.
    //  Updated for Supabase Migration - Phase 3
    //

import SwiftUI
import LinkKit

struct LinkButtonView : View {
    @State var shouldPresentLink = false
    @StateObject var userAccount = UserAccount.shared
    @EnvironmentObject var bankAccountsService: BankAccountsService
    @StateObject var plaidService = PlaidService()
    @State var linkController: LinkController? = nil
    @State var isLoadingLinkToken = false
    @State var showError = false
    @State var errorMessage = ""
    
    var body: some View {
        ZStack(alignment: .leading) {
            Button {
                Task {
                    Logger.d("Add new account pressed!")
                    await loadLinkToken()
                }
            } label: {
                HStack {
                    if isLoadingLinkToken {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 8)
                    }
                    Text(isLoadingLinkToken ? "Loading..." : "Link new account")
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary)
                .cornerRadius(8)
                .padding(.horizontal)
                .shadow(radius: 2)
            }
            .disabled(isLoadingLinkToken)
        }
        .sheet(
            isPresented: $shouldPresentLink,
            onDismiss: {
                shouldPresentLink = false
            },
            content: { [linkController] in
                if let linkController {
                    linkController
                        .ignoresSafeArea(.all)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Initializing Plaid Link...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    /// Load link token from Supabase Edge Function and initialize Plaid Link
    private func loadLinkToken() async {
        isLoadingLinkToken = true
        defer { isLoadingLinkToken = false }

        do {
            Logger.d("Requesting link token from Supabase...")

            // Call Supabase Edge Function to get link token
            let linkToken = try await plaidService.createLinkToken()

            Logger.i("Received link token: \(linkToken)")

            // Generate Plaid Link configuration
            let config = try await generateLinkConfig(linkToken: linkToken)

            // Create Plaid handler
            let handler = Plaid.create(config)

            switch handler {
            case .success(let handler):
                self.linkController = LinkController(handler: handler)
                Logger.i("LinkController initialized successfully")

                // Show the Plaid Link sheet
                shouldPresentLink = true

            case .failure(let error):
                Logger.e("Failed to create Plaid handler: \(error)")
                errorMessage = "Failed to initialize Plaid Link: \(error.localizedDescription)"
                showError = true
            }

        } catch {
            Logger.e("Failed to load link token: \(error)")
            errorMessage = "Failed to load link token: \(error.localizedDescription)"
            showError = true
        }
    }

    private func generateLinkConfig(linkToken: String) async throws -> LinkTokenConfiguration {
        Logger.d("Creating Link config with token \(linkToken)")
        
        var config = LinkTokenConfiguration(token: linkToken) { success in
            Logger.i("Link was finished succesfully! \(success)")
            Task {
                try? await self.saveNewItem(token: success.publicToken, institutionId: success.metadata.institution.id)
            }
        }
        config.onExit = { exit in
            Logger.e("User exited link early \(exit)")
            self.shouldPresentLink = false
        }
        config.onEvent = { event in
            Logger.d("Hit an event \(event.eventName)")
        }
        return config
        
    }
    
    private func saveNewItem(token: String, institutionId: String) async throws {
        Logger.d("Saving new item to server...")

        // Use PlaidService to save the item
        try await plaidService.saveNewItem(
            publicToken: token,
            institutionId: institutionId
        )

        Logger.i("Item saved successfully, refreshing accounts...")

        // Refresh accounts to show the new bank connection
        try? await bankAccountsService.refreshAccounts()

        Logger.i("Accounts refreshed")
    }
}
