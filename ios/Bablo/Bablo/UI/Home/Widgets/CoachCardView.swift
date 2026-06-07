import SwiftUI

struct CoachCardView: View {
    @EnvironmentObject var coachService: CoachService
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.babloTheme) private var theme
    
    @State private var isExpanded = false
    
    var body: some View {
        if let insight = coachService.currentInsight, !coachService.isDismissed {
            VStack(alignment: .leading, spacing: 14) {
                // Top row: Icon, Badge/Header, Close button
                HStack(alignment: .top, spacing: 12) {
                    // Accent Sparkle Badge
                    ZStack {
                        if theme.effects.isPopArt {
                            Rectangle()
                                .fill(theme.colors.accent.color)
                                .frame(width: 38, height: 38)
                                .overlay {
                                    Rectangle()
                                        .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                                }
                        } else {
                            Circle()
                                .fill(theme.colors.accent.color)
                                .frame(width: 38, height: 38)
                                .shadow(color: theme.colors.accent.color.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.colors.accentInk.color)
                    }
                    
                    // Header Text & Headline
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.badge.uppercased())
                            .font(theme.typography.mono(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(theme.colors.textSecondary.color)
                        
                        Text(insight.headline)
                            .font(theme.typography.title(size: 18, weight: theme.effects.isPopArt ? .black : .bold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    // Close/Dismiss Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            coachService.dismissInsight()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss recommendation")
                }
                
                // Body Nudge Text
                Text(insight.nudgeText)
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Animated Expandable Alternative Tip
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(theme.colors.warning.color)
                                .padding(.top, 2)
                            
                            Text(insight.alternativeTip)
                                .font(theme.typography.body(size: 13, weight: .semibold))
                                .foregroundStyle(theme.colors.textPrimary.color)
                                .conditionalItalic(theme.effects.isPopArt)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            theme.effects.isPopArt
                            ? theme.colors.surfaceMuted.color
                            : theme.colors.accent.color.opacity(0.08)
                        )
                        .cornerRadius(theme.effects.isPopArt ? theme.metrics.controlCornerRadius : 12)
                        .overlay {
                            if theme.effects.isPopArt {
                                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                                    .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.borderWidth)
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
                
                // Action Buttons Row
                HStack(spacing: 10) {
                    // Try it / Action Button (Dark)
                    CoachActionButton(
                        title: insight.actionLabel,
                        systemImage: "arrow.up.forward",
                        isPrimary: true
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            navigationState.selectedTab = .coach
                        }
                    }
                    
                    // Tell me more / Show less Button (Light)
                    CoachActionButton(
                        title: isExpanded ? "Show less" : "Tell me more",
                        systemImage: nil,
                        isPrimary: false
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded.toggle()
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                    .stroke(
                        theme.effects.isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                        lineWidth: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                    )
            }
            .shadow(
                color: theme.effects.isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04),
                radius: theme.effects.isPopArt ? 0 : 16,
                x: theme.effects.isPopArt ? 3 : 0,
                y: theme.effects.isPopArt ? 3 : 6
            )
            .padding(.horizontal, Spacing.screenEdge)
        }
    }
    
    // Custom Background Gradient / Solid Fill
    private var cardBackground: some View {
        ZStack {
            if theme.effects.isPopArt {
                theme.colors.surface.color
            } else {
                theme.colors.surface.color
                
                // Soft gradient glow to match design screenshot
                RadialGradient(
                    colors: [
                        theme.colors.accent.color.opacity(0.12),
                        theme.colors.accent.color.opacity(0.0)
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 240
                )
            }
        }
    }
}

// MARK: - Coach Action Button Widget

struct CoachActionButton: View {
    let title: String
    let systemImage: String?
    let isPrimary: Bool
    let action: () -> Void
    
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .font(theme.typography.body(size: 13, weight: theme.effects.isPopArt ? .black : .semibold))
            .foregroundStyle(foregroundStyleColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay {
                if theme.effects.isPopArt {
                    Capsule()
                        .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                } else if !isPrimary {
                    Capsule()
                        .stroke(theme.colors.lineStrong.color.opacity(0.6), lineWidth: 1.0)
                }
            }
            .shadow(
                color: theme.effects.isPopArt ? theme.effects.shadowColor : Color.clear,
                radius: 0,
                x: theme.effects.isPopArt ? 2 : 0,
                y: theme.effects.isPopArt ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isPrimary {
            theme.colors.textPrimary.color
        } else {
            Color.clear
        }
    }
    
    private var foregroundStyleColor: Color {
        if isPrimary {
            theme.colors.surface.color
        } else {
            theme.colors.textPrimary.color
        }
    }
}

struct CoachCardPreviewWrapper: View {
    let theme: BabloTheme
    let service: CoachService
    
    init(theme: BabloTheme) {
        self.theme = theme
        self.service = CoachService()
        self.service.currentInsight = CoachInsight(
            badge: "COACH • JUST NOW",
            headline: "Heads up — Sunday brunch energy",
            nudgeText: "Eats are pacing 38% over last week. Pause coffee for 3 days and you bank ~$24 back.",
            actionLabel: "Try it",
            alternativeTip: "Swapping one takeout order for a home meal will put you back under your daily allowance."
        )
    }
    
    var body: some View {
        VStack {
            Spacer()
            CoachCardView()
                .environmentObject(service)
                .environmentObject(NavigationState())
                .babloTheme(theme)
            Spacer()
        }
        .background(theme == .pop ? Color(hex: "#FFF09A") : Color(hex: "#F8F5EF"))
    }
}

#Preview("Clean Theme Normal") {
    CoachCardPreviewWrapper(theme: .normal)
}

#Preview("Pop Theme Brutalist") {
    CoachCardPreviewWrapper(theme: .pop)
}
