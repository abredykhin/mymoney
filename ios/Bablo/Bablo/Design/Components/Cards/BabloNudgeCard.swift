import SwiftUI

struct BabloNudgeCard: View {
    let badge: String
    let headline: String
    let nudgeText: String
    var alternativeTip: String? = nil
    let actionLabel: String
    var secondaryActionLabel: String? = nil
    
    let onAction: () -> Void
    var onSecondaryAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    @State private var isExpanded = false
    @Environment(\.babloTheme) private var theme
    
    var body: some View {
        let isPopArt = theme.effects.isPopArt
        
        VStack(alignment: .leading, spacing: 14) {
            // Top row: Icon, Badge/Header, Close button
            HStack(alignment: .top, spacing: 12) {
                // Accent Sparkle Badge
                ZStack {
                    if isPopArt {
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
                    Text(badge.uppercased())
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.textSecondary.color)
                    
                    Text(headline)
                        .font(theme.typography.title(size: 18, weight: isPopArt ? .black : .bold))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Close/Dismiss Button
                if let onDismiss = onDismiss {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.colors.textTertiary.color)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss notification")
                }
            }
            
            // Body Nudge Text
            Text(nudgeText)
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
            
            // Animated Expandable Alternative Tip
            if isExpanded, let tip = alternativeTip {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.colors.warning.color)
                            .padding(.top, 2)
                        
                        Text(tip)
                            .font(theme.typography.body(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .conditionalItalic(isPopArt)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        isPopArt
                        ? theme.colors.surfaceMuted.color
                        : theme.colors.accent.color.opacity(0.08)
                    )
                    .cornerRadius(isPopArt ? theme.metrics.controlCornerRadius : 12)
                    .overlay {
                        if isPopArt {
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
                // Main Action Button (Dark)
                Button {
                    onAction()
                } label: {
                    HStack(spacing: 5) {
                        Text(actionLabel)
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(theme.typography.body(size: 13, weight: isPopArt ? .black : .semibold))
                    .foregroundStyle(theme.colors.surface.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.colors.textPrimary.color)
                    .clipShape(Capsule())
                    .overlay {
                        if isPopArt {
                            Capsule()
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                    }
                    .shadow(
                        color: isPopArt ? theme.effects.shadowColor : Color.clear,
                        radius: 0,
                        x: isPopArt ? 2 : 0,
                        y: isPopArt ? 2 : 0
                    )
                }
                .buttonStyle(.plain)
                
                // Secondary Action or "Tell me more" expandable helper
                if alternativeTip != nil || secondaryActionLabel != nil {
                    Button {
                        if let onSecondary = onSecondaryAction {
                            onSecondary()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isExpanded.toggle()
                            }
                        }
                    } label: {
                        Text(secondaryActionLabel ?? (isExpanded ? "Show less" : "Tell me more"))
                            .font(theme.typography.body(size: 13, weight: isPopArt ? .black : .semibold))
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(theme.colors.lineStrong.color.opacity(isPopArt ? 1.0 : 0.6), lineWidth: isPopArt ? theme.metrics.strongBorderWidth : 1.0)
                            }
                            .shadow(
                                color: isPopArt ? theme.effects.shadowColor : Color.clear,
                                radius: 0,
                                x: isPopArt ? 2 : 0,
                                y: isPopArt ? 2 : 0
                            )
                    }
                    .buttonStyle(.plain)
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
                    isPopArt ? theme.colors.lineStrong.color : theme.colors.line.color,
                    lineWidth: isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                )
        }
        .shadow(
            color: isPopArt ? theme.effects.shadowColor : Color.black.opacity(0.04),
            radius: isPopArt ? 0 : 16,
            x: isPopArt ? 3 : 0,
            y: isPopArt ? 3 : 6
        )
    }
    
    private var cardBackground: some View {
        ZStack {
            if theme.effects.isPopArt {
                theme.colors.surface.color
            } else {
                theme.colors.surface.color
                
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
