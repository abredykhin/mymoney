//
//  ContentView.swift
//  Bablo
//
//  Created by Anton Bredykhin on 6/10/24.
//

import SwiftUI
import SwiftData

// Navigation state management
class NavigationState: ObservableObject {
    @Published var selectedTab: TabSelection = .home
    @Published var homeNavPath = NavigationPath()
    @Published var pulseNavPath = NavigationPath()
    @Published var goalsNavPath = NavigationPath()
    @Published var coachNavPath = NavigationPath()
    @Published var meNavPath = NavigationPath()
}

enum TabSelection: CaseIterable, Identifiable {
    case home
    case pulse
    case goals
    case coach
    case me

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Home"
        case .pulse: return "Pulse"
        case .goals: return "Goals"
        case .coach: return "Coach"
        case .me: return "Me"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .pulse: return "waveform.path.ecg"
        case .goals: return "target"
        case .coach: return "lightbulb"
        case .me: return "person"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var accountsService: AccountsService
    @EnvironmentObject var coachService: CoachService
    @StateObject private var navigationState = NavigationState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active
    
    var body: some View {
        if (userAccount.isSignedIn) {
            ZStack {
                currentTabView
            }
            .environmentObject(navigationState)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BabloTabBar(selection: $navigationState.selectedTab)
            }
            .onChange(of: navigationState.selectedTab) { oldValue, newValue in
                if newValue == .home {
                    navigationState.homeNavPath = NavigationPath()
                }
            }
            .onChange(of: scenePhase) {
                Logger.d("ContentView: Scene phase changed from \(previousScenePhase) to \(scenePhase)")
                
                if scenePhase == .background {
                    // Lock the app immediately when it goes to background
                    userAccount.lockApp()
                }
                
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

    @ViewBuilder
    private var currentTabView: some View {
        switch navigationState.selectedTab {
        case .home:
            NavigationStack(path: $navigationState.homeNavPath) {
                HomeView()
                    .environmentObject(navigationState)
            }
        case .pulse:
            NavigationStack(path: $navigationState.pulseNavPath) {
                PulseTabView()
            }
        case .goals:
            NavigationStack(path: $navigationState.goalsNavPath) {
                GoalsTabView()
            }
        case .coach:
            NavigationStack(path: $navigationState.coachNavPath) {
                CoachTabView()
                    .environmentObject(navigationState)
            }
        case .me:
            NavigationStack(path: $navigationState.meNavPath) {
                ProfileView()
            }
        }
    }
}

private struct BabloTabBar: View {
    @Binding var selection: TabSelection
    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(alignment: theme.effects.isPopArt ? .bottom : .center, spacing: 0) {
            ForEach(TabSelection.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    BabloTabBarItem(
                        tab: tab,
                        isSelected: selection == tab
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selection == tab ? "Selected" : "")
            }
        }
        .padding(.horizontal, theme.effects.isPopArt ? 16 : 20)
        .padding(.top, theme.effects.isPopArt ? 8 : 8)
        .padding(.bottom, theme.effects.isPopArt ? 2 : 0)
        .frame(minHeight: theme.effects.isPopArt ? 80 : 64, alignment: .top)
        .background(theme.colors.surface.color)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color)
                .frame(height: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth)
        }
    }
}

private struct BabloTabBarItem: View {
    let tab: TabSelection
    let isSelected: Bool

    @Environment(\.babloTheme) private var theme

    var body: some View {
        if theme.effects.isPopArt && isSelected {
            popSelectedItem
        } else {
            standardItem
        }
    }

    private var standardItem: some View {
        VStack(spacing: theme.effects.isPopArt ? 3 : 4) {
            ZStack {
                if isSelected {
                    selectionBackground
                }

                Image(systemName: tab.symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolVariant(isSelected ? .fill : .none)
                    .foregroundStyle(iconColor)
            }
            .frame(width: theme.effects.isPopArt ? 44 : 44, height: theme.effects.isPopArt ? 30 : 28)

            Text(tab.title)
                .font(labelFont)
                .tracking(theme.effects.isPopArt ? theme.typography.labelTracking : 0)
                .textCase(theme.effects.isPopArt ? .uppercase : nil)
                .modifier(ConditionalItalic(isEnabled: theme.effects.isPopArt))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(height: theme.effects.isPopArt ? 50 : 44, alignment: .top)
    }

    private var popSelectedItem: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 23, weight: .semibold))
                .symbolVariant(.fill)

            Text(tab.title)
                .font(theme.typography.body(size: 11, weight: .black))
                .tracking(theme.typography.labelTracking)
                .textCase(.uppercase)
                .modifier(ConditionalItalic(isEnabled: true))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(theme.colors.accentInk.color)
        .frame(width: 56, height: 60)
        .background(theme.colors.accent.color)
        .overlay {
            Rectangle()
                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
        }
        .shadow(color: theme.effects.shadowColor, radius: 0, x: 4, y: 4)
        .rotationEffect(.degrees(-2))
        .frame(height: 60, alignment: .bottom)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if theme.effects.isPopArt {
            Rectangle()
                .fill(theme.colors.accent.color)
                .frame(width: 44, height: 44)
                .overlay {
                    Rectangle()
                        .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                }
                .shadow(color: theme.effects.shadowColor, radius: 0, x: 4, y: 4)
                .rotationEffect(.degrees(-2))
        } else {
            Capsule()
                .fill(theme.colors.accent.color.opacity(0.28))
                .frame(width: 44, height: 28)
        }
    }

    private var iconColor: Color {
        if isSelected {
            return theme.effects.isPopArt ? theme.colors.accentInk.color : theme.colors.textPrimary.color
        }

        return theme.colors.textTertiary.color
    }

    private var labelColor: Color {
        isSelected ? theme.colors.textPrimary.color : theme.colors.textTertiary.color
    }

    private var iconSize: CGFloat {
        theme.effects.isPopArt ? 21 : 20
    }

    private var labelFont: Font {
        if theme.effects.isPopArt {
            return theme.typography.body(size: 12, weight: .black)
        }

        return theme.typography.body(size: 12, weight: isSelected ? .bold : .semibold)
    }
}

private struct ConditionalItalic: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.italic()
        } else {
            content
        }
    }
}

private struct BabloEmptyTabView: View {
    var body: some View {
        Color.clear
            .babloScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Tabs Normal") {
    ContentViewPreviewHost(theme: .normal)
}

#Preview("Tabs Pop") {
    ContentViewPreviewHost(theme: .pop)
}

private struct ContentViewPreviewHost: View {
    let theme: BabloTheme

    @StateObject private var userAccount = UserAccount()
    @StateObject private var accountsService = AccountsService()
    @StateObject private var authManager = AuthManager()
    @StateObject private var budgetService = BudgetService()
    @StateObject private var transactionsService = TransactionsService()
    @StateObject private var plaidService = PlaidService()
    @StateObject private var coachService = CoachService()

    var body: some View {
        ContentView()
            .environmentObject(userAccount)
            .environmentObject(accountsService)
            .environmentObject(authManager)
            .environmentObject(budgetService)
            .environmentObject(transactionsService)
            .environmentObject(plaidService)
            .environmentObject(coachService)
            .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
            .babloTheme(theme)
            .onAppear {
                userAccount.isSignedIn = true
            }
    }
}
