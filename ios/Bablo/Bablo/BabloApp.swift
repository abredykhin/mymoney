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
    
    let coreDataStack = CoreDataStack.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userAccount)
                .environmentObject(bankAccountsService)
                .task {
                    userAccount.checkCurrentUser()
                }
                .environment(\.managedObjectContext, coreDataStack.viewContext)
        }
    }
}
