//
//  AuthViewModel.swift
//  mymoney
//
//  Created by Anton Bredykhin on 1/21/24.
//

import Foundation

protocol AuthFormValidationProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    private let defaults = UserDefaults.standard

    func signIn(email: String, password: String) async throws {
        print("Sign In...")
    }
    
    func createAccount(name: String, email: String, password: String) {
        print("Create Account...")
    }
    
    func signOut() {
        print("Sign Out...")
    }
    
    
}
