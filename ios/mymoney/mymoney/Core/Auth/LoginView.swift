//
//  LoginView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import SwiftUI

extension Color {
    static let primaryColor = Color(red: 52/255, green: 152/255, blue: 219/255) // Light blue
    static let backgroundColor = Color(red: 255/255, green: 255/255, blue: 255/255) // White background
    static let inputBackgroundColor = Color(red: 240/255, green: 240/255, blue: 240/255) // Light gray
    static let errorColor = Color(red: 255/255, green: 100/255, blue: 100/255) // Soft pinkish-red
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignIn = true
    @State private var showError = false
    @EnvironmentObject var userAccount: UserAccount
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color.inputBackgroundColor)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .shadow(radius: 1)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color.inputBackgroundColor)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .shadow(radius: 1)

                Button {
                    Task {
                        if (isSignIn) {
                            debugPrint("Sign In button pressed!")
                            try await userAccount.signIn(email:email, password:password)
                        } else {
                            debugPrint("Sign Up button pressed!")
                            try await userAccount.createAccount(name:"", email: email, password: password)
                        }
                    }
                } label: {
                    Text(isSignIn ? "Sign In" : "Sign Up")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.primaryColor)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .shadow(radius: 2)
                        .scaleEffect(isSignIn ? 1.0 : 1.1)
//                        .opacity(formIsValid ? 1.0 : 0.5)
//                        .disabled(!formIsValid)
                }
                .padding(.top)

                if showError {
                    Text("Incorrect password. Please try again.")
                        .foregroundColor(Color.errorColor)
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
                            .foregroundColor(.primaryColor)
                    }
                }
                .padding()

            }
            .navigationTitle(isSignIn ? "Sign In" : "Sign Up")
            .background(Color.backgroundColor.edgesIgnoringSafeArea(.all))
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.backgroundColor, Color.primary]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all))
        }
    }
    

    // Dummy function to simulate incorrect password
    func passwordIsIncorrect() -> Bool {
        // Add your actual password validation logic here
        return true
    }
}

#Preview {
    LoginView()
        .withPreviewEnv()
}

//struct LoginView_Previews: PreviewProvider {
//    static let userAccount = UserAccount()
//    
//    static var previews: some View {
//        LoginView()
//            .environmentObject(userAccount)
//    }
//}
