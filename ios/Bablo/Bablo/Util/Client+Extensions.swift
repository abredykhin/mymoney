    //
    //  Client+Extensions.swift
    //  mymoney
    //
    //  Created by Anton Bredykhin on 2/19/24.
    //

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

extension Client {
    
    static func getServerUrl() -> URL {
        var serverUrl: URL
//        if isRunningOnSimulator() {
//            Logger.d("Client is using local dev server!")
//            serverUrl = try! Servers.server2()
//        } else {
//            Logger.d("Client is using production server!")
            serverUrl = try! Servers.server1()
//        }
        return serverUrl
    }
}

private func isRunningOnSimulator() -> Bool {
#if targetEnvironment(simulator)
    return true
#else
    return false
#endif
}
