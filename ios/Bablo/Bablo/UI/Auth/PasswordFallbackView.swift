//
//  PasswordFallbackView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//  Updated for Supabase Migration - Phase 2
//

import SwiftUI

struct PasswordFallbackView: View {
    @EnvironmentObject var userAccount: UserAccount
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isAuthenticating = false
    @State private var showMigrationNotice = false
    var onComplete: (Bool) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    // Check if this is a Supabase user (migrated to Apple Sign In)
                    if isSupabaseUser() {
                        // Show migration notice for Supabase users
                        Image(systemName: "applelogo")
                            .font(.system(size: 60))
                            .foregroundColor(.primary)
                            .padding(.bottom)

                        Text("Password Authentication Unavailable")
                            .font(.headline)

                        Text("Your account uses Sign in with Apple. Please sign out and sign back in with Apple to continue.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("Sign Out") {
                            userAccount.signOut()
                            onComplete(false)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else {
                        // Legacy password authentication (for users not yet migrated)
                        Text("Enter your credentials to continue")
                            .font(.headline)

                        if userAccount.currentUser != nil {
                            // If we know the email already, show it and just ask for password
                            Text(userAccount.currentUser?.name ?? "")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.bottom)
                        } else {
                            // Otherwise ask for both email and password
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }


                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)

                        Button("Authenticate") {
                            authenticate()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(isAuthenticating)

                        // Show migration reminder for legacy users
                        VStack(spacing: 8) {
                            Text("Using old credentials?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Consider signing out and using Sign in with Apple for better security.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 40)
                
                // Overlay blur and loading indicator when authenticating
                if isAuthenticating {
                    Color.black
                        .opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .blur(radius: 3)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Authenticating...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(25)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(.systemGray6).opacity(0.8))
                    )
                }
            }
            .navigationTitle("Password Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Authentication Failed"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    /// Check if the current user is using Supabase (Apple Sign In)
    /// Supabase users have email addresses in a specific format or don't have legacy credentials
    private func isSupabaseUser() -> Bool {
        // Check if user's ID is a UUID (Supabase format)
        // Supabase user IDs are UUIDs, legacy IDs are numeric strings
        guard let userId = userAccount.currentUser?.id else {
            return false
        }

        // If the ID is a valid UUID, it's a Supabase user
        if UUID(uuidString: userId) != nil {
            return true
        }

        return false
    }

    func authenticate() {
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showError = true
            return
        }
        
        // Use the email we already know if available
        let userEmail = userAccount.currentUser?.name ?? email
        
        guard !userEmail.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }
        
        isAuthenticating = true
        
        Task {
            do {
                try await userAccount.signIn(email: userEmail, password: password)
                
                // If we get here, authentication was successful
                DispatchQueue.main.async {
                    isAuthenticating = false
                    onComplete(true)
                }
            } catch {
                DispatchQueue.main.async {
                    isAuthenticating = false
                    errorMessage = "Invalid credentials. Please try again."
                    showError = true
                    onComplete(false)
                }
            }
        }
    }
}
