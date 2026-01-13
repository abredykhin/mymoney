//
//  EmailAuthService.swift
//  Bablo
//
//  Created for Email Authentication with Supabase
//

import Foundation
import Supabase

@MainActor
class EmailAuthService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    /// Send OTP code to email address
    /// Automatically creates user if doesn't exist, or signs in if exists
    func sendVerification(email: String) async throws {
        Logger.i("EmailAuthService: Sending verification to \(email)")
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signInWithOTP(email: email, )
            Logger.i("EmailAuthService: OTP sent successfully")
        } catch {
            Logger.e("EmailAuthService: Failed to send OTP: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Verify OTP code
    /// On success, user is automatically signed in
    func verifyCode(email: String, code: String) async throws {
        Logger.i("EmailAuthService: Verifying code for \(email)")
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            Logger.i("EmailAuthService: Successfully verified and signed in")
            Logger.d("EmailAuthService: User ID: \(session.user.id)")
        } catch {
            Logger.e("EmailAuthService: Failed to verify OTP: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
