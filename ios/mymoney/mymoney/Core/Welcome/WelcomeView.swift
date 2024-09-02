//
//  WelcomeView.swift
//  mymoney
//
//  Created by Anton Bredykhin on 4/25/24.
//

import Foundation
import AuthenticationServices
import SwiftUI

struct WelcomeView : View {
    var body: some View {
        VStack(alignment: .center) {
            Text("Welcome to BabloApp.")
                .padding(.top)
            
            Spacer()
            
            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.email]
            } onCompletion: { result in
                switch result {
                    case .success(let authResults):
                        print("Authorisation successful")
                case .failure(let error):
                        print("Authorisation failed: \(error.localizedDescription)")
                }
            }
            .frame(height: 50)
            .padding()
            .cornerRadius(8)
            // black button
            .signInWithAppleButtonStyle(.black)
            // white button
//            .signInWithAppleButtonStyle(.white)
            // white with border
//            .signInWithAppleButtonStyle(.whiteOutline)
            
            
            Button(action: {}, label: {
                Text("Sign up with email")
            })
            .frame(height: 50)
            
            Text("Have an account? Sign in")
                .frame(height: 25)
        }
    }
}

#Preview {
    WelcomeView()
        .withPreviewEnv()
}
