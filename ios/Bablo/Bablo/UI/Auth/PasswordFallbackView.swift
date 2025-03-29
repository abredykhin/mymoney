//
//  PasswordFallbackView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import SwiftUI

struct PasswordFallbackView: View {
    @EnvironmentObject var userAccount: UserAccount
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isAuthenticating = false
    var onComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
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
