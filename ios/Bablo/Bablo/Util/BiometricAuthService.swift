    //
    //  FaceIdAuthService.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 3/28/25.
    //

import Foundation
import LocalAuthentication

@MainActor
class BiometricsAuthService: ObservableObject {
    enum BiometricType {
        case none
        case faceID
        case touchID
    }
    
    enum AuthError: Error {
        case noHardware
        case notConfigured
        case notAvailable
        case authFailed
        case userCanceled
        case systemCancel
        case other
    }
    
    // Check if biometric authentication is available
    func biometricType() -> BiometricType {
        let context = LAContext()
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            Logger.d("BiometricsAuthService: Device doesn't support biometrics")
            return .none
        }
        
        if #available(iOS 11.0, *) {
            switch context.biometryType {
            case .faceID:
                Logger.d("BiometricsAuthService: Device supports FaceID")
                return .faceID
            case .touchID:
                Logger.d("BiometricsAuthService: Device supports TouchID")
                return .touchID
            default:
                Logger.d("BiometricsAuthService: Device supports no biometrics")
                return .none
            }
        } else {
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touchID : .none
        }
    }
    
    // Comprehensive authentication function that tries biometrics, then device passcode
    func authenticateUser(reason: String, completion: @escaping (Bool) -> Void) {
        Logger.d("BiometricsAuthService: Starting user authentication with reason: \(reason)")
        
        // First try biometric authentication if available
        let bioType = biometricType()
        if bioType != .none {
            // Device supports biometrics, try that first
            authenticate(reason: reason) { result in
                switch result {
                case .success:
                    Logger.d("BiometricsAuthService: Biometric authentication successful")
                    completion(true)
                case .failure(let error):
                    Logger.d("BiometricsAuthService: Biometric authentication failed: \(error), trying device passcode")
                    
                    // For certain failures, try device passcode
                    if error == .userCanceled || error == .notAvailable || error == .authFailed {
                        self.authenticateWithDevicePasscode(reason: reason, completion: completion)
                    } else {
                        // For other errors (like no hardware), fail
                        completion(false)
                    }
                }
            }
        } else {
            // No biometrics support, go straight to device passcode
            authenticateWithDevicePasscode(reason: reason, completion: completion)
        }
    }
    
    // Try to authenticate with device passcode
    private func authenticateWithDevicePasscode(reason: String, completion: @escaping (Bool) -> Void) {
        Logger.d("BiometricsAuthService: Attempting to authenticate with device passcode")
        let context = LAContext()
        var error: NSError?
        
        // Check if device passcode is set
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // Authenticate with device passcode
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        Logger.d("BiometricsAuthService: Device passcode authentication successful")
                        completion(true)
                    } else {
                        Logger.d("BiometricsAuthService: Device passcode authentication failed: \(error?.localizedDescription ?? "unknown error")")
                        completion(false)
                    }
                }
            }
        } else {
            // Device passcode not set
            Logger.d("BiometricsAuthService: Device passcode not available: \(error?.localizedDescription ?? "unknown error")")
            completion(false)
        }
    }
    
    private func authenticate(reason: String, completion: @escaping (Result<Bool, AuthError>) -> Void) {
        Logger.d("BiometricsAuthService: Starting biometric authentication with reason: \(reason)")
        
        let context = LAContext()
        var error: NSError?
        
            // Check if device supports biometric authentication
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                Logger.e("BiometricsAuthService: Error checking policy: \(error.localizedDescription), code: \(error.code)")
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    completion(.failure(.noHardware))
                case LAError.biometryNotEnrolled.rawValue:
                    completion(.failure(.notConfigured))
                default:
                    completion(.failure(.notAvailable))
                }
            } else {
                Logger.e("BiometricsAuthService: Unknown error checking policy")
                completion(.failure(.notAvailable))
            }
            return
        }
        
            // Request authentication
        Logger.d("BiometricsAuthService: Requesting biometric authentication")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    Logger.d("BiometricsAuthService: Authentication successful")
                    completion(.success(true))
                    return
                }
                
                    // Handle authentication errors
                if let error = error as? LAError {
                    Logger.e("BiometricsAuthService: Authentication failed with error: \(error.localizedDescription), code: \(error.code)")
                    switch error.code {
                    case .userCancel:
                        completion(.failure(.userCanceled))
                    case .systemCancel:
                        completion(.failure(.systemCancel))
                    case .authenticationFailed:
                        completion(.failure(.authFailed))
                    default:
                        completion(.failure(.other))
                    }
                } else {
                    Logger.e("BiometricsAuthService: Authentication failed with unknown error")
                    completion(.failure(.other))
                }
            }
        }
    }
}
