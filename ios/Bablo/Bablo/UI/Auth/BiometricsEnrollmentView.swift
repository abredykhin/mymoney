//
//  BiometricsEnrollmentView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import SwiftUI

struct BiometricEnrollmentView: View {
    @EnvironmentObject var userAccount: UserAccount
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = BiometricsAuthService()
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: authService.biometricType() == .faceID ? "faceid" : "touchid")
                .font(.system(size: 70))
                .foregroundColor(.accentColor)
            
            Text("Enable \(authService.biometricType() == .faceID ? "Face ID" : "Touch ID")?")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You can use \(authService.biometricType() == .faceID ? "Face ID" : "Touch ID") to quickly and securely access your financial data.")
                .multilineTextAlignment(.center)
                .padding()
            
            HStack(spacing: 20) {
                Button("Skip") {
                    userAccount.enableBiometricAuthentication(false)
                    dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                
                Button("Enable") {
                    // Perform a test authentication to ensure it works
                    authService.authenticateUser(reason: "Set up biometric authentication") { success in
                        if (success) {
                            Logger.d("Test biometric auth success. Storing the value")
                            userAccount.enableBiometricAuthentication(true)
                            dismiss()
                        } else {
                            Logger.d("Test biometric failed. Storing the value")
                            userAccount.enableBiometricAuthentication(false)
                            dismiss()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
