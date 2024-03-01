//
//  AuthMiddleware.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import OpenAPIRuntime
import Foundation
import HTTPTypes

/// A client middleware that injects a value into the `Authorization` header field of the request.
struct AuthenticationMiddleware {

    /// The value for the `Authorization` header field.
    private let token: String?

    /// Creates a new middleware.
    /// - Parameter value: The value for the `Authorization` header field.
    package init(token: String?) { self.token = token }
}

extension AuthenticationMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        // Adds the `Authorization` header field with the provided value.
        if let token = self.token {
            let authHeaderValue = "Bearer " + token
            request.headerFields[.authorization] = authHeaderValue
        }
        return try await next(request, body, baseURL)
    }
}
