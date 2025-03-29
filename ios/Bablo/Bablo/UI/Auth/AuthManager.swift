//
//  AuthManager.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/29/25.
//

import Foundation

import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var lastAuthenticationTime: Date?
    private let authTimeoutInterval: TimeInterval = 30 // 30 seconds timeout
    
    init() {
        // Initialize with nil, forcing first authentication
        lastAuthenticationTime = nil
    }
    
    func recordSuccessfulAuthentication() {
        lastAuthenticationTime = Date()
        Logger.d("AuthManager: Recorded successful authentication at \(lastAuthenticationTime!)")
    }
    
    func shouldRequireAuthentication() -> Bool {
        guard let lastAuth = lastAuthenticationTime else {
            Logger.d("AuthManager: No previous authentication found, requiring authentication")
            return true
        }
        
        let timeSinceLastAuth = Date().timeIntervalSince(lastAuth)
        let shouldAuth = timeSinceLastAuth > authTimeoutInterval
        
        Logger.d("AuthManager: Time since last auth: \(timeSinceLastAuth) seconds, requiring auth: \(shouldAuth)")
        return shouldAuth
    }
}
