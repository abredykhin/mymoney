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
    @StateObject private var transactionsService = TransactionsService()
    @State private var isRefreshing = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    if isRefreshing {
                        ProgressView()
                            .tint(.accentColor)
                    }

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
                        .environmentObject(transactionsService)
                    Spacer()                    
                }
            }
            .refreshable {
                checkConnectivityAndRefresh()
            }
            .task {
                checkConnectivityAndRefresh(forceRefresh: false)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationView {
                    ProfileView()
                }
            }
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
                isRefreshing = true
                
                do {
                    // Refresh both accounts and transactions
                    try await bankAccountsService.refreshAccounts(forceRefresh: forceRefresh)
                    try await transactionsService.fetchRecentTransactions(forceRefresh: forceRefresh)
                } catch {
                    Logger.e("Failed to refresh data: \(error)")
                }
                
                isRefreshing = false
            }
        }
    }
}
