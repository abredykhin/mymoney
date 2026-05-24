import SwiftUI

struct HomeTopBarView: View {
    @EnvironmentObject var userAccount: UserAccount
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.babloTheme) private var theme
    
    private let hasUnreadNotifications = false
    private let dateRangeLabel: String
    private let titleText: String?
    private let actionSystemName: String
    private let actionAccessibilityLabel: String
    private let action: (() -> Void)?

    init(
        dateRangeLabel: String = "MON → SUN",
        titleText: String? = nil,
        actionSystemName: String = "bell",
        actionAccessibilityLabel: String = "Notifications",
        action: (() -> Void)? = nil
    ) {
        self.dateRangeLabel = dateRangeLabel
        self.titleText = titleText
        self.actionSystemName = actionSystemName
        self.actionAccessibilityLabel = actionAccessibilityLabel
        self.action = action
    }
    
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
            VStack(alignment: .leading, spacing: 2) {
                dateRangeText
                greetingText
            }
            
            Spacer()
            
            HStack(spacing: theme.effects.isPopArt ? 12 : 10) {
                notificationButton
                avatarButton
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, theme.metrics.screenPadding)
        .padding(.top, Spacing.sm)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var dateRangeText: some View {
        if theme.effects.isPopArt {
            Text(dateRangeLabel)
                .font(theme.typography.mono(size: 11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(theme.colors.textSecondary.color)
        } else {
            Text(dateRangeLabel)
                .font(theme.typography.body(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.textTertiary.color)
        }
    }
    
    @ViewBuilder
    private var greetingText: some View {
        if let titleText {
            Text(theme.effects.isPopArt ? "\(titleText.uppercased()) !!" : titleText)
                .font(theme.effects.isPopArt ? theme.typography.display(size: 26, weight: .black) : theme.typography.title(size: 26, weight: .bold))
                .tracking(theme.effects.isPopArt ? theme.typography.displayTracking : 0)
                .modifier(HomeTopBarConditionalItalic(isEnabled: theme.effects.isPopArt))
                .foregroundStyle(theme.colors.textPrimary.color)
        } else if theme.effects.isPopArt {
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
            action?()
        } label: {
            ZStack {
                if theme.effects.isPopArt {
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
                    
                    Image(systemName: actionSystemName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                } else {
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
                    
                    Image(systemName: actionSystemName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(actionAccessibilityLabel)
    }
    
    private var avatarButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                navigationState.selectedTab = .me
            }
        } label: {
            ZStack {
                if theme.effects.isPopArt {
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

private struct HomeTopBarConditionalItalic: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.italic()
        } else {
            content
        }
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
