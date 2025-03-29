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
                // Check if we're transitioning from background to active
                if scenePhase == .active && (previousScenePhase == .background || previousScenePhase == .inactive) {
                    Logger.d("ContentView: App will enter foreground from background")
                    userAccount.requireBiometricAuth()
                } else {
                    Logger
                        .d(
                            "ContentView: App is entering \(scenePhase) phase from previous phase: \(previousScenePhase) "
                        )
                }
                previousScenePhase = scenePhase
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
