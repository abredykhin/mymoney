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
    @StateObject var coachService = CoachService()
    @StateObject var streakService = StreakService()
    @StateObject var subService = SubscriptionsService()
    @StateObject var goalsService = GoalsService()
    @StateObject var pulseService = PulseService()
    @StateObject var homeBreakdownService = HomeBreakdownService()
    @State private var showBiometricEnrollment = false
    @State private var showAuthView = false
    @State private var isPresentingRequiredOnboarding = false
    @AppStorage("babloThemeVariant") private var babloThemeVariant = BabloTheme.normal.rawValue
    @Environment(\.scenePhase) var scenePhase

    private var selectedTheme: BabloTheme {
        BabloTheme(rawValue: babloThemeVariant) ?? .normal
    }
    
    private var skipAuthForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting-skip-auth")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if skipAuthForUITests || userAccount.isSignedIn {
                    if userAccount.profile == nil {
                        BabloScreenBackground {
                            ProgressView()
                                .tint(.primary)
                        }
                        .babloTheme(selectedTheme)
                    } else if isPresentingRequiredOnboarding || userAccount.needsOnboarding {
                        OnboardingWizard {
                            isPresentingRequiredOnboarding = false
                        }
                        .environmentObject(userAccount)
                        .environmentObject(accountsService)
                        .environmentObject(authManager)
                        .environmentObject(budgetService)
                        .environmentObject(transactionsService)
                        .environmentObject(plaidService)
                        .environmentObject(coachService)
                        .environmentObject(streakService)
                        .environmentObject(subService)
                        .environmentObject(goalsService)
                        .environmentObject(pulseService)
                        .environmentObject(homeBreakdownService)
                        .babloTheme(selectedTheme)
                        .onAppear {
                            isPresentingRequiredOnboarding = true
                        }
                    } else {
                        // Always show ContentView, but blur it when authentication is needed
                        ContentView()
                            .environmentObject(userAccount)
                            .environmentObject(accountsService)
                            .environmentObject(authManager)
                            .environmentObject(budgetService)
                            .environmentObject(transactionsService)
                            .environmentObject(plaidService)
                            .environmentObject(coachService)
                            .environmentObject(streakService)
                            .environmentObject(subService)
                            .environmentObject(goalsService)
                            .environmentObject(pulseService)
                            .environmentObject(homeBreakdownService)
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
                            .babloTheme(selectedTheme)
                    }
                } else {
                        // Login/welcome view
                    WelcomeView()
                        .environmentObject(userAccount)
                        .babloTheme(selectedTheme)
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
                    if plaidService.currentHandler != nil {
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
            .onChange(of: userAccount.profile) { _, _ in
                if userAccount.needsOnboarding {
                    isPresentingRequiredOnboarding = true
                }
            }
            .onChange(of: userAccount.currentUser?.id) { oldUserID, newUserID in
                guard oldUserID != newUserID else { return }

                isPresentingRequiredOnboarding = false
                accountsService.clearCache()
                transactionsService.clearCache()
                budgetService.clearCache()
                goalsService.clearCache()
                pulseService.clearData()
                subService.allRecurringStreams = []
                subService.subscriptions = []

                if newUserID != nil {
                    Logger.i("BabloApp: Cleared user-scoped caches for auth transition")
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
