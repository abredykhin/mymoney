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
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .blur(radius: (userAccount.isBiometricEnabled && !userAccount.isBiometricallyAuthenticated) ? 20 : 0)
                        .animation(.default, value: userAccount.isBiometricallyAuthenticated)
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
                        .sheet(isPresented: $showBiometricEnrollment) {
                            BiometricEnrollmentView()
                                .environmentObject(userAccount)
                        }
                        .sheet(isPresented: $showAuthView) {
                            AuthenticationView(onAuthenticated: {
                                userAccount.isBiometricallyAuthenticated = true
                                showAuthView = false
                            }, onSignOut: {
                                userAccount.signOut()
                                showAuthView = false
                            })
                            .environmentObject(userAccount)
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
        Logger.d("BabloApp: Attempting to authenticate with biometrics")
        let authService = BiometricsAuthService()
        authService.authenticate(reason: "Unlock BabloApp to access your financial data") { result in
            switch result {
            case .success:
                Logger.d("BabloApp: Biometric authentication successful")
                userAccount.isBiometricallyAuthenticated = true
            case .failure:
                Logger.d("BabloApp: Biometric authentication failed")
                showAuthView = true
            }
        }
    }
}
