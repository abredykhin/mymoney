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
            Logger.d("FaceIdAuthService: Device doesn't support biometrics")
            return .none
        }
        
        if #available(iOS 11.0, *) {
            switch context.biometryType {
            case .faceID:
                Logger.d("FaceIdAuthService: Device supports FaceID")
                return .faceID
            case .touchID:
                Logger.d("FaceIdAuthService: Device supports TouchID")
                return .touchID
            default:
                Logger.d("FaceIdAuthService: Device supports no biometrics")
                return .none
            }
        } else {
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touchID : .none
        }
    }
    
    // Authenticate with biometrics
    func authenticate(reason: String, completion: @escaping (Result<Bool, AuthError>) -> Void) {
        Logger.d("FaceIdAuthService: Starting authentication with reason: \(reason)")
        
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports biometric authentication
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                Logger.e("FaceIdAuthService: Error checking policy: \(error.localizedDescription)")
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    completion(.failure(.noHardware))
                case LAError.biometryNotEnrolled.rawValue:
                    completion(.failure(.notConfigured))
                default:
                    completion(.failure(.notAvailable))
                }
            } else {
                completion(.failure(.notAvailable))
            }
            return
        }
        
        // Request authentication
        Logger.d("FaceIdAuthService: Requesting biometric authentication")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    Logger.d("FaceIdAuthService: Authentication successful")
                    completion(.success(true))
                    return
                }
                
                    // Handle authentication errors
                if let error = error as? LAError {
                    Logger.e("FaceIdAuthService: Authentication failed with error: \(error.localizedDescription)")
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
                    Logger.e("FaceIdAuthService: Authentication failed with unknown error")
                    completion(.failure(.other))
                }
            }
        }
    }
}
