//
//  PhoneAuthService.swift
//  Bablo
//
//  Created for Phone Authentication with Supabase
//

import Foundation
import Supabase

@MainActor
class PhoneAuthService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    /// Send OTP code to phone number
    /// Automatically creates user if doesn't exist, or signs in if exists
    func sendVerification(phoneNumber: String) async throws {
        Logger.i("PhoneAuthService: Sending verification to \(phoneNumber)")
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signInWithOTP(phone: phoneNumber)
            Logger.i("PhoneAuthService: OTP sent successfully")
        } catch {
            Logger.e("PhoneAuthService: Failed to send OTP: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Verify OTP code
    /// On success, user is automatically signed in
    func verifyCode(phoneNumber: String, code: String) async throws {
        Logger.i("PhoneAuthService: Verifying code for \(phoneNumber)")
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.verifyOTP(
                phone: phoneNumber,
                token: code,
                type: .sms
            )

            Logger.i("PhoneAuthService: Successfully verified and signed in")
            Logger.d("PhoneAuthService: User ID: \(session.user.id)")
        } catch {
            Logger.e("PhoneAuthService: Failed to verify OTP: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
