//
//  AccountsRepository.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

class AccountsRepository {
    private let client: Client
    
    init() {
        client = Client(serverURL: Client.getServerUrl(), transport: URLSessionTransport())
    }
    
//    func getAccounts() -> [Account]? {
//        Logger.w("Requesting list of accounts")
//
//        return nil
//    }
}
