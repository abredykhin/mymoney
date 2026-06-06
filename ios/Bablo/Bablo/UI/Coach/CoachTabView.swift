import SwiftUI

struct CoachTabView: View {
    @EnvironmentObject var coachService: CoachService
    @Environment(\.babloTheme) private var theme
    @State private var showingRefreshSuccess = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Header Banner
                headerBanner
                
                if coachService.isLoading {
                    loadingState
                } else if let insight = coachService.currentInsight {
                    insightDetailContent(insight)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 40)
        }
        .babloScreenBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COACH")
                    .font(theme.typography.mono(size: 14, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .tracking(2.0)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if theme.effects.isPopArt {
                Text("AI COACHING 🦾")
                    .font(theme.typography.display(size: 32, weight: .black))
                    .italic()
                    .foregroundStyle(theme.colors.textPrimary.color)
            } else {
                Text("AI Financial Coach")
                    .font(theme.typography.title(size: 28, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary.color)
            }
            
            Text("Bablo's automated coach uses Gemini to analyze your last 14 days of transactions to find leaks, optimize subscriptions, and keep you under budget.")
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
                .lineSpacing(4)
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.md)
    }
    
    // MARK: - Loaded Content Details
    
    private func insightDetailContent(_ insight: CoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Main Insight Details Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(insight.badge)
                        .font(theme.typography.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.colors.success.color)
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Text("ACTIVE")
                        .font(theme.typography.mono(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.colors.success.color.opacity(0.12))
                        .foregroundStyle(theme.colors.success.color)
                        .clipShape(Capsule())
                }
                
                Text(insight.headline)
                    .font(theme.typography.display(size: 22, weight: .black))
                    .conditionalItalic(theme.effects.isPopArt)
                    .foregroundStyle(theme.colors.textPrimary.color)
                
                Text(insight.nudgeText)
                    .font(theme.typography.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineSpacing(3)
                
                Divider()
                    .background(theme.colors.line.color)
                
                // Action buttons inside tab details
                HStack {
                    Text("Recommendation Pacing:")
                        .font(theme.typography.body(size: 13, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                    Spacer()
                    Text("Immediate")
                        .font(theme.typography.mono(size: 13, weight: .bold))
                        .foregroundStyle(theme.colors.warning.color)
                }
            }
            .babloCard(tone: .surface)
            .padding(.horizontal, Spacing.screenEdge)
            
            // Alternative Tip Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.warning.color)
                    
                    Text("COACH TIP")
                        .font(theme.typography.mono(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
                
                Text(insight.alternativeTip)
                    .font(theme.typography.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(
                theme.effects.isPopArt
                ? theme.colors.surfaceMuted.color
                : theme.colors.accent.color.opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous)
                    .stroke(
                        theme.colors.lineStrong.color,
                        lineWidth: theme.effects.isPopArt ? theme.metrics.strongBorderWidth : theme.metrics.borderWidth
                    )
            }
            .padding(.horizontal, Spacing.screenEdge)
            
            // Refresh Analysis Button
            Button {
                triggerAnalysis()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("REFRESH COACH ANALYSIS")
                }
                .font(theme.typography.body(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.surface.color)
                .frame(maxWidth: .infinity, minHeight: theme.metrics.buttonHeight)
                .background(theme.colors.textPrimary.color)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
                .overlay {
                    if theme.effects.isPopArt {
                        RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous)
                            .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                    }
                }
                .shadow(
                    color: theme.effects.isPopArt ? theme.effects.shadowColor : Color.clear,
                    radius: 0,
                    x: theme.effects.isPopArt ? 3 : 0,
                    y: theme.effects.isPopArt ? 3 : 0
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 10)
            
            if showingRefreshSuccess {
                Text("Analysis completed successfully!")
                    .font(theme.typography.mono(size: 12, weight: .bold))
                    .foregroundStyle(theme.colors.success.color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(theme.colors.accent.color)
                .scaleEffect(1.5)
                .padding(.top, 40)
            
            Text("Coach is analyzing transactions...")
                .font(theme.typography.mono(size: 13, weight: .bold))
                .foregroundStyle(theme.colors.textSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(theme.colors.textTertiary.color)
                .padding(.bottom, 8)
            
            Text("No insights generated yet")
                .font(theme.typography.title(size: 20, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary.color)
            
            Text("Link your bank accounts or record transactions so the AI Coach can analyze your spending leaks.")
                .font(theme.typography.body(size: 14, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button {
                triggerAnalysis()
            } label: {
                Text("ANALYZE SPENDING NOW")
                    .font(theme.typography.body(size: 15, weight: .bold))
                    .foregroundStyle(theme.colors.accentInk.color)
                    .padding(.horizontal, 24)
                    .frame(height: theme.metrics.buttonHeight)
                    .background(theme.colors.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous))
                    .overlay {
                        if theme.effects.isPopArt {
                            RoundedRectangle(cornerRadius: theme.metrics.buttonCornerRadius, style: .continuous)
                                .stroke(theme.colors.lineStrong.color, lineWidth: theme.metrics.strongBorderWidth)
                        }
                    }
                    .shadow(
                        color: theme.effects.isPopArt ? theme.effects.shadowColor : Color.clear,
                        radius: 0,
                        x: theme.effects.isPopArt ? 3 : 0,
                        y: theme.effects.isPopArt ? 3 : 0
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Trigger Method
    
    private func triggerAnalysis() {
        Task {
            do {
                _ = try await coachService.fetchCoachInsights(force: true)
                withAnimation {
                    showingRefreshSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showingRefreshSuccess = false
                    }
                }
            } catch {
                Logger.e("CoachTabView: Failed to trigger coach insights refresh: \(error)")
            }
        }
    }
}

struct CoachTabPreviewWrapper: View {
    let theme: BabloTheme
    let service: CoachService
    
    init(theme: BabloTheme, hasInsight: Bool) {
        self.theme = theme
        self.service = CoachService()
        if hasInsight {
            self.service.currentInsight = CoachInsight(
                badge: "COACH • JUST NOW",
                headline: "Heads up — Sunday brunch energy",
                nudgeText: "Eats are pacing 38% over last week. Pause coffee for 3 days and you bank ~$24 back.",
                actionLabel: "Try it",
                alternativeTip: "Swapping one takeout order for a home meal will put you back under your daily allowance."
            )
        }
    }
    
    var body: some View {
        CoachTabView()
            .environmentObject(service)
            .environmentObject(NavigationState())
            .babloTheme(theme)
    }
}

#Preview("Empty State Clean") {
    CoachTabPreviewWrapper(theme: .normal, hasInsight: false)
}

#Preview("Loaded State Clean") {
    CoachTabPreviewWrapper(theme: .normal, hasInsight: true)
}

#Preview("Loaded State Pop") {
    CoachTabPreviewWrapper(theme: .pop, hasInsight: true)
}
