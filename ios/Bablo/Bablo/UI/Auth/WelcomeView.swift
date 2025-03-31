    //
    //  WelcomeView.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 6/10/24.
    //
import SwiftUI

struct WelcomeView : View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignIn = true
    @State private var isValidEmail = false
    @State private var isValidPassword = false
    @State private var showError = false
    @EnvironmentObject var userAccount: UserAccount
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Bablo App").font(.largeTitle).fontWeight(.black).padding(.bottom, 42)
                
                EmailTextField(isValidEmail: $isValidEmail, email: $email)
                
                PasswordTextView(isValidPassword: $isValidPassword, password: $password)
                
                SignInButton(isValidEmail: $isValidEmail, isValidPassword: $isValidPassword, isSignIn: $isSignIn) {
                    Task {
                        if (isSignIn) {
                            debugPrint("Sign In button pressed!")
                            do {
                                try await userAccount.signIn(email:email, password:password)
                            } catch {
                                showError = true
                            }
                        } else {
                            debugPrint("Sign Up button pressed!")
                            do {
                                try await userAccount.createAccount(name:"", email: email, password: password)
                            } catch {
                                showError = true
                            }
                        }
                    }
                }
                
                if showError {
                    Spacer()
                    Text("Incorrect password. Please try again.")
                        .foregroundColor(Color.red)
                        .padding()
                        .transition(.opacity)
                }
                
                Spacer()
                
                HStack {
                    Text(isSignIn ? "Don't have an account?" : "Already have an account?")
                    Button(action: {
                        withAnimation {
                            isSignIn.toggle()
                        }
                        showError = false
                    }) {
                        Text(isSignIn ? "Sign Up" : "Sign In")
                            .bold()
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                
            }
            .padding()
            .background(Color.white.edgesIgnoringSafeArea(.all))
        }
    }
}

struct EmailTextField : View {
    @Binding var isValidEmail: Bool
    @Binding var email: String
    
    var body: some View {
        return VStack(alignment: .leading, spacing: 11) {
            TextField("", text: $email, prompt: Text("Email").foregroundColor(.black))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textContentType(.emailAddress)
                .padding()
                .cornerRadius(8)
                .shadow(radius: 1)
                .onChange(of: email) { oldVal, newValue in
                    isValidEmail = email.isValid(regexes: [Regex.login, Regex.email].compactMap { "\($0.rawValue)" })
                }
        }
    }
}

struct PasswordTextView : View {
    @Binding var isValidPassword: Bool
    @Binding var password: String
    
    var body: some View {
        return VStack(alignment: .leading, spacing: 11) {
            SecureField("", text: $password, prompt: Text("Password").foregroundColor(.black))
                .onChange(of: password) { old, newValue in
                    isValidPassword = password.isValid(regexes: [Regex.password].compactMap { "\($0.rawValue)" })
                }
                .textContentType(.password)
                .cornerRadius(8)
                .padding(.horizontal)
                .shadow(radius: 1)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
    }
}

struct SignInButton : View {
    @Binding var isValidEmail: Bool
    @Binding var isValidPassword: Bool
    @Binding var isSignIn: Bool
    
    var onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Text(isSignIn ? "Sign In" : "Sign Up")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.primary)
                .cornerRadius(8)
                .padding(.horizontal)
                .shadow(radius: 2)
                .scaleEffect(isSignIn ? 1.0 : 1.1)
                .opacity(isValidEmail && isValidPassword ? 1.0 : 0.5)
            
        }
        .disabled(!isValidEmail || !isValidPassword)
        .padding(.top)
    }
}

extension String {
    func isValid(regexes: [String]) -> Bool {
        for regex in regexes {
            let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
            if predicate.evaluate(with: self) == true {
                return true
            }
        }
        return false
    }
}

enum Regex: String {
    case login = "^[a-zA-Z][a-zA-Z0-9]{2,49}$"
    case email = "^[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,49}$"
    case password = "^[a-zA-Z][a-zA-Z0-9]{7,11}$"
}

#Preview {
    WelcomeView()
}
