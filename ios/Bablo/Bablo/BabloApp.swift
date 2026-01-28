    //
    //  BabloApp.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 6/10/24.
    //

import SwiftUI
import SwiftData

@main
struct BabloApp: App {
    @StateObject var userAccount = UserAccount.shared
    @StateObject var accountsService = AccountsService()
    @StateObject var authManager = AuthManager.shared
    @StateObject var budgetService = BudgetService()
    @StateObject var transactionsService = TransactionsService()
    @StateObject var plaidService = PlaidService()
    @State private var showBiometricEnrollment = false
    @State private var showAuthView = false
    @Environment(\.scenePhase) var scenePhase

    let coreDataStack = CoreDataStack.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if userAccount.isSignedIn {
                        // Always show ContentView, but blur it when authentication is needed
                    ContentView()
                        .environmentObject(userAccount)
                        .environmentObject(accountsService)
                        .environmentObject(authManager)
                        .environmentObject(budgetService)
                        .environmentObject(transactionsService)
                        .environmentObject(plaidService)
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .blur(radius: (userAccount.isBiometricEnabled && !userAccount.isBiometricallyAuthenticated) || showAuthView ? 20 : 0)
                        .animation(.default, value: userAccount.isBiometricallyAuthenticated)
                        .animation(.default, value: showAuthView)
                        .overlay {
                            // Don't show biometric auth overlay if Plaid Link is active (OAuth in progress)
                            if (userAccount.isBiometricEnabled && !userAccount.isBiometricallyAuthenticated && scenePhase == .active && plaidService.currentHandler == nil) {
                                Color.black.opacity(0.01)
                                    .edgesIgnoringSafeArea(.all)
                                    .onAppear {
                                        Logger.d("BabloApp: Authentication overlay appeared - triggering biometrics")
                                        authenticateWithBiometrics()
                                    }
                            }
                        }
                        .sheet(isPresented: $showAuthView) {
                            AuthenticationView(onAuthenticated: {
                                userAccount.isBiometricallyAuthenticated = true
                                authManager.recordSuccessfulAuthentication()
                                showAuthView = false
                            }, onSignOut: {
                                userAccount.signOut()
                                showAuthView = false
                            })
                            .environmentObject(userAccount)
                            .interactiveDismissDisabled(true)
                        }
                        .sheet(isPresented: $showBiometricEnrollment) {
                            BiometricEnrollmentView()
                                .environmentObject(userAccount)
                                .interactiveDismissDisabled(true)
                        }
                } else {
                        // Login/welcome view
                    WelcomeView()
                        .environmentObject(userAccount)
                }
            }
            .onOpenURL { url in
                // Handle OAuth redirect from Plaid
                Logger.d("BabloApp: Received URL: \(url.absoluteString)")

                // Check if this is a Plaid OAuth redirect
                if url.host == "babloapp.com" && url.path.starts(with: "/plaid/redirect") {
                    Logger.i("BabloApp: Plaid OAuth redirect received")

                    // In SDK 5.x+, OAuth redirects are handled automatically by the SDK
                    // The handler just needs to be retained, which we do via plaidService.currentHandler
                    if let handler = plaidService.currentHandler {
                        Logger.i("BabloApp: Handler is retained - SDK will process OAuth redirect automatically")
                    } else {
                        Logger.e("BabloApp: No active Plaid handler found for OAuth redirect - Link may have been dismissed")
                    }
                }
            }
            .task {
                userAccount.checkCurrentUser()
                userAccount.checkBiometricSettings()
            }
            .onChange(of: userAccount.isSignedIn) {
                if userAccount.isSignedIn {
                    Logger.d("BabloApp: User signed in detected, checking auth requirements")
                    
                    // Always require authentication when sign in state changes to true
                    userAccount.requireBiometricAuth()
                    
                    // Check if this is the first sign-in and biometrics haven't been configured
                    if !userAccount.hasBiometricPromptBeenShown() {
                        // Only show enrollment if device supports biometrics
                        let authService = BiometricsAuthService()
                        if authService.biometricType() != .none {
                            showBiometricEnrollment = true
                            userAccount.markBiometricPromptAsShown()
                        }
                    }
                }
            }
        }
    }
    
    func authenticateWithBiometrics() {
        Logger.d("BabloApp: Attempting to authenticate user")
        let authService = BiometricsAuthService()
        
        authService.authenticateUser(reason: "Unlock BabloApp to access your financial data") { success in
            if success {
                Logger.d("BabloApp: Authentication successful")
                userAccount.isBiometricallyAuthenticated = true
                authManager.recordSuccessfulAuthentication()
            } else {
                Logger.d("BabloApp: Authentication failed, showing auth view")
                showAuthView = true
            }
        }
    }
}
