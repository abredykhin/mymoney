//
//  HomeView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/2/24.
//

import Foundation
import SwiftUI
import Network

struct HomeView: View {
    @EnvironmentObject var bankAccountsService: BankAccountsService
    @State private var isOffline = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    if bankAccountsService.isUsingCachedData && isOffline {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("You're offline. Showing cached data.")
                            Spacer()
                            Button("Try Again") {
                                checkConnectivityAndRefresh()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    TotalBalanceView()
                    BankListView()
                    Spacer()
                    RecentTransactionsView()
                    Spacer()                    
                }
            }
            .refreshable {
                checkConnectivityAndRefresh()
            }
            .task {
                checkConnectivityAndRefresh(forceRefresh: false)
            }
                // Rest of your toolbar code...
        }
        .onAppear {
                // Check network status when view appears
            checkNetworkStatus()
        }
    }
    
    private func checkNetworkStatus() {
            // Using NWPathMonitor to check network status
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    private func checkConnectivityAndRefresh(forceRefresh: Bool = true) {
        Task {
            if !isOffline || forceRefresh {
                try? await bankAccountsService.refreshAccounts(forceRefresh: forceRefresh)
            }
        }
    }
}
