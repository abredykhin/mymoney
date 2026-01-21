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
        VStack(spacing: Spacing.xl) {
            Image(systemName: authService.biometricType() == .faceID ? "faceid" : "touchid")
                .font(Typography.displayLarge)
                .foregroundColor(ColorPalette.primary)
            
            Text("Enable \(authService.biometricType() == .faceID ? "Face ID" : "Touch ID")?")
                .font(Typography.h2)
                .fontWeight(.bold)
            
            Text("You can use \(authService.biometricType() == .faceID ? "Face ID" : "Touch ID") to quickly and securely access your financial data.")
                .font(Typography.body)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(Spacing.md)
            
            HStack(spacing: Spacing.md) {
                Button("Skip") {
                    userAccount.enableBiometricAuthentication(false)
                    dismiss()
                }
                .secondaryButton()
                
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
                .primaryButton()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
    }
}
