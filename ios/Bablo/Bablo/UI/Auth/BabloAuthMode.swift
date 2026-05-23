//
//  BabloAuthMode.swift
//  Bablo
//

enum BabloAuthMode: Equatable {
    case landing
    case signIn
    case signUp

    var title: String {
        switch self {
        case .landing:
            "Money that doesn't feel like math."
        case .signIn:
            "Welcome back."
        case .signUp:
            "Make an account."
        }
    }

    var subtitle: String {
        switch self {
        case .landing:
            "Track spending, hit goals, and actually understand where your money goes - in 90 seconds a week."
        case .signIn:
            "Sign in to get back to your stack."
        case .signUp:
            "Takes about a minute. We promise."
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .landing:
            "Get started"
        case .signIn:
            "Sign in"
        case .signUp:
            "Continue"
        }
    }

    var toggleTitle: String {
        switch self {
        case .landing:
            "I already have an account"
        case .signIn:
            "Don't have an account? Sign up"
        case .signUp:
            "Already have one? Sign in"
        }
    }
}
