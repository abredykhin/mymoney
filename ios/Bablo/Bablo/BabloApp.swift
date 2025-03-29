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
    @StateObject var bankAccountsService = BankAccountsService()
    @StateObject var authManager = AuthManager.shared
    @State private var showBiometricEnrollment = false
    @State private var showAuthView = false
    
    let coreDataStack = CoreDataStack.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if userAccount.isSignedIn {
                        // Always show ContentView, but blur it when authentication is needed
                    ContentView()
                        .environmentObject(userAccount)
                        .environmentObject(bankAccountsService)
                        .environmentObject(authManager)
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .blur(radius: (userAccount.isBiometricEnabled && !userAccount.isBiometricallyAuthenticated) || showAuthView ? 20 : 0)
                        .animation(.default, value: userAccount.isBiometricallyAuthenticated)
                        .animation(.default, value: showAuthView)
                        .overlay {
                            if (userAccount.isBiometricEnabled && !userAccount.isBiometricallyAuthenticated) {
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
            .task {
                userAccount.checkCurrentUser()
                userAccount.checkBiometricSettings()
                
                    // Always require authentication on app launch
                if userAccount.isSignedIn {
                    Logger.d("BabloApp: App launched with signed-in user, requiring authentication")
                    userAccount.requireBiometricAuth() // This will check with AuthManager
                }
                
                    // Check if this is the first sign-in and biometrics haven't been configured
                if userAccount.isSignedIn && !userAccount.hasBiometricPromptBeenShown() {
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
