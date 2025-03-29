//
//  AuthenticationView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authService = BiometricsAuthService()
    @EnvironmentObject var userAccount: UserAccount
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showPasswordFallback = false
    @State private var showSignOutConfirmation = false
    
    var onAuthenticated: () -> Void
    var onSignOut: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)
                
                Text("Authentication Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Use biometric authentication or your password to access your account")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: authenticate) {
                    HStack {
                        Image(systemName: authService.biometricType() == .faceID ? "faceid" : "touchid")
                        Text("Try \(authService.biometricType() == .faceID ? "Face ID" : "Touch ID") Again")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button("Use Password Instead") {
                    showPasswordFallback = true
                }
                .padding(.top, 8)
                
                Spacer()
                
                Button("Sign Out") {
                    showSignOutConfirmation = true
                }
                .foregroundColor(.red)
                .padding(.bottom, 20)
            }
            .padding()
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Authentication Failed"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showPasswordFallback) {
                PasswordFallbackView { success in
                    if success {
                        onAuthenticated()
                    }
                    showPasswordFallback = false
                }
                .environmentObject(userAccount)
            }
            .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
            } message: {
                Text("Are you sure you want to sign out of your account?")
            }
            .navigationTitle("Authentication")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func authenticate() {
        authService.authenticateUser(reason: "Unlock BabloApp to access your financial data") { success in
            if success {
                // Update enrollment state if needed
                if !userAccount.isBiometricEnabled {
                    Logger.d("AuthenticationView: User used biometrics successfully but enrollment was false. Updating to true.")
                    userAccount.enableBiometricAuthentication(true)
                }
                
                // Record successful authentication time will be done in BabloApp
                onAuthenticated()
            } else {
                errorMessage = "Authentication failed. Please try again or use your password."
                showError = true
            }
        }
    }
}
