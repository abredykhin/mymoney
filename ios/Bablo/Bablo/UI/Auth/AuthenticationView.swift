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
        authService.authenticate(reason: "Unlock BabloApp to access your financial data") { result in
            switch result {
            case .success:
                onAuthenticated()
            case .failure(let error):
                switch error {
                case .noHardware:
                    errorMessage = "This device doesn't support biometric authentication."
                    showPasswordFallback = true
                case .notConfigured:
                    errorMessage = "Please set up Face ID in your device settings first."
                case .notAvailable:
                    errorMessage = "Biometric authentication is not available."
                    showPasswordFallback = true
                case .authFailed:
                    errorMessage = "Authentication failed. Please try again."
                case .userCanceled:
                    errorMessage = "Authentication was canceled."
                case .systemCancel:
                    errorMessage = "Authentication was canceled by the system."
                case .other:
                    errorMessage = "Authentication failed. Please try again later."
                }
                
                if error != .userCanceled && error != .systemCancel {
                    showError = true
                }
            }
        }
    }
}
