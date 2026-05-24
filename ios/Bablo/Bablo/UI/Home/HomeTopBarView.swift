import SwiftUI

struct HomeTopBarView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.babloTheme) private var theme
    
    private let hasUnreadNotifications = false
    
    private var userName: String {
        HomeGreetingResolver.displayName(
            profileFirstName: userAccount.profile?.firstName,
            user: userAccount.currentUser
        )
    }
    
    private var firstInitial: String {
        String(userName.prefix(1)).uppercased()
    }
    
    var body: some View {
        HStack(alignment: .center) {
            // Left Column: Date range and Greeting
            VStack(alignment: .leading, spacing: 2) {
                dateRangeText
                greetingText
            }
            
            Spacer()
            
            // Right Side: Notifications and User Avatar Buttons
            HStack(spacing: theme.effects.isPopArt ? 12 : 10) {
                notificationButton
                avatarButton
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var dateRangeText: some View {
        if theme.effects.isPopArt {
            Text("MON → SUN")
                .font(theme.typography.mono(size: 11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(theme.colors.textSecondary.color)
        } else {
            Text("MON → SUN")
                .font(theme.typography.body(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)
        }
    }
    
    @ViewBuilder
    private var greetingText: some View {
        if theme.effects.isPopArt {
            Text("YO, \(userName.uppercased()) ‼️")
                .font(theme.typography.display(size: 26, weight: .black))
                .italic()
                .foregroundStyle(theme.colors.textPrimary.color)
        } else {
            HStack(spacing: 4) {
                Text("Yo, \(userName)")
                    .font(theme.typography.title(size: 26, weight: .bold))
                Text("👋")
                    .font(.system(size: 26))
            }
            .foregroundStyle(theme.colors.textPrimary.color)
        }
    }
    
    private var notificationButton: some View {
        Button {
            // Notifications are not wired yet; keep this as a visual affordance only.
        } label: {
            ZStack {
                if theme.effects.isPopArt {
                    // Pop Art: brutalist white square with thick black border
                    Rectangle()
                        .fill(theme.colors.surface.color)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Rectangle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                        .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                        .overlay(alignment: .topTrailing) {
                            if hasUnreadNotifications {
                                Rectangle()
                                    .fill(theme.colors.danger.color)
                                    .frame(width: 10, height: 10)
                                    .border(theme.colors.lineStrong.color, width: 1.5)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                } else {
                    // Normal Clean: soft circular/rounded surface
                    Circle()
                        .fill(theme.colors.surface.color)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }
                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                        .overlay(alignment: .topTrailing) {
                            if hasUnreadNotifications {
                                Circle()
                                    .fill(theme.colors.danger.color)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                        }
                    
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var avatarButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                navigationState.selectedTab = .me
            }
        } label: {
            ZStack {
                if theme.effects.isPopArt {
                    // Pop Art: brutalist pink square with thick black border and shadow
                    Rectangle()
                        .fill(theme.colors.avatarPink.color)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Rectangle()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                        .shadow(color: theme.effects.shadowColor, radius: 0, x: 3, y: 3)
                    
                    Text(firstInitial)
                        .font(theme.typography.body(size: 16, weight: .black))
                        .foregroundStyle(theme.colors.accentInk.color)
                        .italic()
                } else {
                    // Normal Clean: elegant pink circle
                    Circle()
                        .fill(theme.colors.avatarPink.color)
                        .frame(width: 40, height: 40)
                        .shadow(color: theme.colors.avatarPink.color.opacity(0.2), radius: 6, x: 0, y: 3)
                    
                    Text(firstInitial)
                        .font(theme.typography.body(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

enum HomeGreetingResolver {
    static func displayName(profileFirstName: String?, user: User?) -> String {
        let profileName = profileFirstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionName = user?.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let profileName, !profileName.isEmpty {
            return profileName
        }

        if let sessionName, !sessionName.isEmpty, sessionName != user?.emailUsernameFallback {
            return sessionName
        }

        return "there"
    }
}

private extension User {
    var emailUsernameFallback: String? {
        email?.components(separatedBy: "@").first
    }
}

// MARK: - Previews

#Preview("Clean Theme Light") {
    let user = UserAccount.shared
    user.currentUser = User(id: "1", name: "Mia", token: "", email: "mia@example.com")
    
    return HomeTopBarView()
        .environmentObject(user)
        .environmentObject(NavigationState())
        .babloTheme(.normal)
        .preferredColorScheme(.light)
        .padding()
        .background(Color(hex: "#F8F5EF"))
}

#Preview("Pop Theme Light") {
    let user = UserAccount.shared
    user.currentUser = User(id: "1", name: "Mia", token: "", email: "mia@example.com")
    
    return HomeTopBarView()
        .environmentObject(user)
        .environmentObject(NavigationState())
        .babloTheme(.pop)
        .preferredColorScheme(.light)
        .padding()
        .background(Color(hex: "#FFF09A"))
}
