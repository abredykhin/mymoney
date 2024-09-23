    //
    //  BabloApp.swift
    //  Bablo
    //
    //  Created by Anton Bredykhin on 6/10/24.
    //

import SwiftUI
import SwiftData

@main
struct BabloApp: App {
    @StateObject var userAccount = UserAccount.shared
    @StateObject var bankAccountsService = BankAccountsService()
    
        //    var sharedModelContainer: ModelContainer = {
        //        let schema = Schema([
        //            Item.self,
        //        ])
        //        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        //
        //        do {
        //            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        //        } catch {
        //            fatalError("Could not create ModelContainer: \(error)")
        //        }
        //    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userAccount)
                .environmentObject(bankAccountsService)
                .task {
                    userAccount.checkCurrentUser()
                }
        }
        
            //        .modelContainer(sharedModelContainer)
    }
}
