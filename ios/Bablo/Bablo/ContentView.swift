//
//  ContentView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/10/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var navigationState = NavigationState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active
    
    var body: some View {
        if (userAccount.isSignedIn) {
            TabView(selection: $navigationState.selectedTab) {
                // Wrap HomeView in NavigationStack for better navigation management
                NavigationStack(path: $navigationState.homeNavPath) {
                    HomeView()
                        .environmentObject(navigationState)
                }
                .tabItem {
                    Label("Overview", systemImage: "house.fill")
                }
                .tag(TabSelection.home)
                
                // Wrap AllTransactionsView in NavigationStack
                NavigationStack(path: $navigationState.transactionsNavPath) {
                    AllTransactionsView()
                        .environmentObject(navigationState)
                }
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                .tag(TabSelection.transactions)
            }
            .onChange(of: navigationState.selectedTab) { oldValue, newValue in
                // Clear navigation stack when switching tabs
                if newValue == .home {
                    navigationState.homeNavPath = NavigationPath()
                } else if newValue == .transactions {
                    navigationState.transactionsNavPath = NavigationPath()
                }
            }
            .onChange(of: scenePhase) {
                Logger.d("ContentView: Scene phase changed from \(previousScenePhase) to \(scenePhase)")
                
                // If coming back to active from inactive OR background
                if scenePhase == .active && (previousScenePhase == .background || previousScenePhase == .inactive) {
                    // Always check with auth manager whether auth is needed
                    userAccount.requireBiometricAuth()
                }
                
                previousScenePhase = scenePhase
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Logger.d("ContentView: App will enter foreground via notification")
                userAccount.requireBiometricAuth()
            }
            .onAppear {
                previousScenePhase = scenePhase
            }
        } else {
            WelcomeView()
        }
    }
}

// Navigation state management
class NavigationState: ObservableObject {
    @Published var selectedTab: TabSelection = .home
    @Published var homeNavPath = NavigationPath()
    @Published var transactionsNavPath = NavigationPath()
}

enum TabSelection {
    case home
    case transactions
}

#Preview {
    ContentView()
}
