    //
    //  WelcomeView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 6/10/24.
    //  Updated for Supabase Migration - Phase 2
    //
import SwiftUI
import AuthenticationServices

struct WelcomeView : View {
    @StateObject private var appleSignInCoordinator = SignInWithAppleCoordinator()
    @State private var showError = false
    @State private var showPhoneSignUp = false
    @EnvironmentObject var userAccount: UserAccount

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // App Logo/Icon
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                // App Name
                Text("Bablo App")
                    .font(.largeTitle)
                    .fontWeight(.black)

                Text("Your Personal Finance Manager")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)

                // Sign in with Apple Button
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        // The coordinator handles the sign-in flow
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                .padding(.horizontal, 40)
                .onTapGesture {
                    Logger.i("WelcomeView: Sign in with Apple button tapped")
                    appleSignInCoordinator.signInWithApple()
                }

                if appleSignInCoordinator.isLoading {
                    ProgressView()
                        .padding()
                }

                // Sign Up with Phone Button
                Button(action: { showPhoneSignUp = true }) {
                    Text("Sign Up with Phone")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                Spacer()

                // Privacy Notice
                Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .padding()
            .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    showError = false
                }
            } message: {
                Text(appleSignInCoordinator.errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: appleSignInCoordinator.errorMessage) { _, newErrorMessage in
                if newErrorMessage != nil {
                    showError = true
                }
            }
            .sheet(isPresented: $showPhoneSignUp) {
                PhoneSignUpView()
                    .environmentObject(userAccount)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(UserAccount.shared)
}
