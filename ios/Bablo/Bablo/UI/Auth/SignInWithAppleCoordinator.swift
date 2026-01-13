//
//  SignInWithAppleCoordinator.swift
//  Bablo
//
//  Created for Supabase Migration - Phase 2
//

import Foundation
import AuthenticationServices
import Supabase
import CryptoKit

/// Coordinates Sign in with Apple authentication flow with Supabase
@MainActor
class SignInWithAppleCoordinator: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    private let supabase = SupabaseManager.shared.client

    /// Start the Sign in with Apple flow
    func signInWithApple() {
        Logger.i("SignInWithAppleCoordinator: Starting Sign in with Apple flow")

        // Generate a random nonce for security
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    /// Generate a random nonce string
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// SHA256 hash of input string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Logger.i("SignInWithAppleCoordinator: Authorization completed")

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Logger.e("SignInWithAppleCoordinator: Invalid credential type")
            self.errorMessage = "Invalid credential type"
            return
        }

        guard let nonce = currentNonce else {
            Logger.e("SignInWithAppleCoordinator: Missing nonce")
            self.errorMessage = "Authentication error occurred"
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            Logger.e("SignInWithAppleCoordinator: Unable to fetch identity token")
            self.errorMessage = "Unable to fetch identity token"
            return
        }

        Logger.d("SignInWithAppleCoordinator: Got ID token, signing in to Supabase")

        Task {
            do {
                isLoading = true

                // Sign in to Supabase with Apple ID token
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idTokenString,
                        nonce: nonce
                    )
                )

                Logger.i("SignInWithAppleCoordinator: Successfully signed in to Supabase")
                Logger.d("SignInWithAppleCoordinator: User ID: \(session.user.id)")

                // Update user metadata with full name if available (Apple only provides this on first sign-in)
                if let fullName = appleIDCredential.fullName {
                    try await updateUserMetadata(fullName: fullName)
                }

                isLoading = false
            } catch {
                Logger.e("SignInWithAppleCoordinator: Failed to sign in: \(error)")
                self.errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.e("SignInWithAppleCoordinator: Authorization failed: \(error.localizedDescription)")

        // Check if user cancelled
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                Logger.i("SignInWithAppleCoordinator: User cancelled sign in")
            case .failed:
                Logger.e("SignInWithAppleCoordinator: Authorization failed")
            case .invalidResponse:
                Logger.e("SignInWithAppleCoordinator: Invalid response")
            case .notHandled:
                Logger.e("SignInWithAppleCoordinator: Not handled")
            case .unknown:
                Logger.e("SignInWithAppleCoordinator: Unknown error")
            case .notInteractive:
                Logger.e("SignInWithAppleCoordinator: Not interactive")
            case .matchedExcludedCredential:
                Logger.e("SignInWithAppleCoordinator: Matched excluded credential")
            @unknown default:
                Logger.e("SignInWithAppleCoordinator: Unknown authorization error")
            }
        }

        self.errorMessage = error.localizedDescription
        isLoading = false
    }

    /// Update user metadata with full name from Apple
    /// Apple only provides the full name during the first sign-in
    private func updateUserMetadata(fullName: PersonNameComponents) async throws {
        var displayName = ""

        if let givenName = fullName.givenName, let familyName = fullName.familyName {
            displayName = "\(givenName) \(familyName)"
        } else if let givenName = fullName.givenName {
            displayName = givenName
        } else if let familyName = fullName.familyName {
            displayName = familyName
        }

        guard !displayName.isEmpty else {
            Logger.d("SignInWithAppleCoordinator: No display name to update")
            return
        }

        Logger.d("SignInWithAppleCoordinator: Updating user metadata with name: \(displayName)")

        try await supabase.auth.update(
            user: UserAttributes(
                data: ["full_name": .string(displayName)]
            )
        )

        Logger.i("SignInWithAppleCoordinator: Updated user metadata successfully")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window scene available")
        }
        return window
    }
}
