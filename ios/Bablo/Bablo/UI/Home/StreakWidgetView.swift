//
//  StreakWidgetView.swift
//  Bablo
//

import SwiftUI

struct StreakWidgetView: View {
    @EnvironmentObject var streakService: StreakService
    @Environment(\.babloTheme) private var theme
    let onTap: () -> Void

    init(onTap: @escaping () -> Void = {}) {
        self.onTap = onTap
    }

    private var currentStreak: Int {
        streakService.userStreak?.currentStreak ?? 0
    }

    private var maxStreak: Int {
        streakService.userStreak?.maxStreak ?? 0
    }

    private var streakMessage: String {
        guard streakService.userStreak != nil else {
            return "No bank accounts linked yet."
        }
        if currentStreak == 0 {
            return "over budget today. Start fresh!"
        } else if currentStreak >= maxStreak && maxStreak > 0 {
            return "under budget. Personal best."
        } else {
            return "under budget. Keep it up!"
        }
    }

    private var statusPills: [Bool] {
        var status = streakService.userStreak?.last10DaysStatus ?? []
        if status.count < 10 {
            status.append(contentsOf: Array(repeating: false, count: 10 - status.count))
        }
        return Array(status.prefix(10)).reversed()
    }

    var body: some View {
        let isPopArt = theme.effects.isPopArt
        HomeWidgetCard(
            title: "STREAK",
            titleIconName: "flame.fill",
            titleIconColor: currentStreak > 0 ? theme.colors.danger.color : theme.colors.textTertiary.color
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Large number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 34, weight: isPopArt ? .black : .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Text("days")
                        .font(theme.typography.body(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }

                // Subtitle message
                Text(streakMessage)
                    .font(theme.typography.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 32, alignment: .topLeading)

                // Pill status chart
                HStack(spacing: 5) {
                    ForEach(0..<10) { index in
                        let isToday = (index == 9)
                        let isUnderBudget = index < statusPills.count ? statusPills[index] : false
                        
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isUnderBudget ? theme.colors.accent.color : theme.colors.surfaceMuted.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .overlay {
                                if isToday {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(theme.colors.lineStrong.color, lineWidth: isPopArt ? 2.5 : 1.2)
                                } else if isPopArt {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.0)
                                }
                            }
                    }
                }
                .padding(.top, 4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open saving streak")
    }
}

struct StreakDetailView: View {
    @EnvironmentObject private var streakService: StreakService
    @Environment(\.babloTheme) private var theme

    private var streak: UserStreak {
        streakService.userStreak ?? UserStreak(
            currentStreak: 0,
            maxStreak: 0,
            last10DaysStatus: Array(repeating: false, count: 10)
        )
    }

    private var title: String {
        streak.currentStreak > 0 ? "You're on fire" : "Start the chain"
    }

    private var subtitle: String {
        streak.currentStreak > 0
            ? "Every day under budget keeps it alive"
            : "Stay under budget today to start your streak"
    }

    private var progressTitle: String {
        streak.daysToNextMilestone == 0
            ? "Legend run unlocked"
            : "Next: \(streak.nextMilestoneDay)-day milestone"
    }

    var body: some View {
        ZStack {
            theme.colors.appBackground.color.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    hero
                    progress
                    statStrip
                    calendarSection
                    freezeCard
                    milestones
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if streakService.userStreak == nil && !streakService.isLoading {
                try? await streakService.fetchUserStreak()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SAVING STREAK")
                .font(theme.typography.mono(size: 12, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(theme.colors.textTertiary.color)

            Text(title)
                .font(theme.typography.display(size: 29, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(subtitle)
                .font(theme.typography.body(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary.color)
                .lineLimit(2)
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.colors.accent.color)
                    .shadow(color: theme.colors.accent.color.opacity(0.36), radius: 18, x: 0, y: 10)

                Image(systemName: "flame.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(theme.colors.accentInk.color)
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(streak.currentStreak)")
                        .font(theme.typography.display(size: 50, weight: .black))
                        .foregroundStyle(theme.colors.textPrimary.color)
                        .monospacedDigit()

                    Text("days")
                        .font(theme.typography.body(size: 21, weight: .bold))
                        .foregroundStyle(theme.colors.textSecondary.color)
                }

                HStack(spacing: 8) {
                    if streak.currentStreak > 0 && streak.currentStreak >= streak.maxStreak {
                        Text("PERSONAL BEST")
                            .font(theme.typography.mono(size: 13, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(theme.colors.accent.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(theme.colors.accentDeep.color)
                            .clipShape(Capsule())
                    }

                    Text(streak.daysToNextMilestone == 0 ? "Keep the run alive" : "\(streak.daysToNextMilestone) to the next milestone")
                        .font(theme.typography.body(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(progressTitle.uppercased())
                    .font(theme.typography.mono(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(theme.colors.textTertiary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                Text("\(min(streak.currentStreak, streak.nextMilestoneDay))/\(streak.nextMilestoneDay)")
                    .font(theme.typography.mono(size: 13, weight: .black))
                    .foregroundStyle(theme.colors.textSecondary.color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.surfaceMuted.color)
                        .overlay {
                            Capsule()
                                .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                        }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.accentPressed.color, theme.colors.accent.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, proxy.size.width * streak.milestoneProgress))
                }
            }
            .frame(height: 13)
        }
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            StreakStatCell(label: "CURRENT", value: "\(streak.currentStreak)d")
            Divider().frame(height: 42)
            StreakStatCell(label: "LONGEST", value: "\(streak.maxStreak)d")
            Divider().frame(height: 42)
            StreakStatCell(label: "MARKERS", value: "\(streak.earnedFreezeCount)")
        }
        .padding(.vertical, 4)
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT DAYS")
                .font(theme.typography.mono(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(theme.colors.textTertiary.color)

            StreakCalendarGrid(cells: streak.detailCalendarCells)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                alignment: .leading,
                spacing: 8
            ) {
                StreakLegend(color: theme.colors.accent.color, label: StreakCalendarDayStatus.underBudget.displayLabel)
                StreakLegend(color: theme.colors.surfaceMuted.color, label: StreakCalendarDayStatus.overBudget.displayLabel, outlined: true, showsDot: true)
                StreakLegend(color: theme.colors.surface.color.opacity(0.55), label: StreakCalendarDayStatus.unknown.displayLabel, outlined: true)
            }
        }
    }

    private var freezeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(theme.colors.info.color.opacity(0.18))

                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.colors.info.color)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak.earnedFreezeCount) freeze markers")
                    .font(theme.typography.body(size: 18, weight: .black))
                    .foregroundStyle(theme.colors.textPrimary.color)

                Text(streak.freezeMarkerSummary)
                    .font(theme.typography.body(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(0..<max(streak.earnedFreezeCount, 1), id: \.self) { index in
                    Circle()
                        .fill(index < streak.earnedFreezeCount ? theme.colors.info.color : theme.colors.line.color)
                        .frame(width: 9, height: 9)
                }
            }
        }
        .babloCard(tone: .muted, padding: 14)
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MILESTONES")
                .font(theme.typography.mono(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(theme.colors.textTertiary.color)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(streak.detailMilestones) { milestone in
                    StreakMilestoneCard(milestone: milestone)
                }
            }
        }
    }

}

private struct StreakStatCell: View {
    let label: String
    let value: String

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(theme.typography.mono(size: 12, weight: .black))
                .tracking(2)
                .foregroundStyle(theme.colors.textTertiary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(theme.typography.display(size: 28, weight: .black))
                .foregroundStyle(theme.colors.textPrimary.color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

private struct StreakCalendarGrid: View {
    let cells: [StreakCalendarCell]

    @Environment(\.babloTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(theme.typography.mono(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.textTertiary.color)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    StreakCalendarCellView(cell: cell)
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(scale(for: cell))
                        .opacity(opacity(for: cell))
                        .animation(animation(for: index, cell: cell), value: hasAppeared)
                }
            }
        }
        .onAppear {
            hasAppeared = false
            DispatchQueue.main.async {
                hasAppeared = true
            }
        }
    }

    private func scale(for cell: StreakCalendarCell) -> CGFloat {
        guard !reduceMotion, cell.status == .underBudget || cell.status == .today else { return 1 }
        return hasAppeared ? 1 : 0.7
    }

    private func opacity(for cell: StreakCalendarCell) -> Double {
        guard !reduceMotion, cell.status == .underBudget || cell.status == .today else { return 1 }
        return hasAppeared ? 1 : 0.25
    }

    private func animation(for index: Int, cell: StreakCalendarCell) -> Animation? {
        guard !reduceMotion, cell.status == .underBudget || cell.status == .today else { return nil }
        return .spring(response: 0.36, dampingFraction: 0.68)
            .delay(Double(index) * 0.012)
    }
}

private struct StreakCalendarCellView: View {
    let cell: StreakCalendarCell

    @Environment(\.babloTheme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .overlay {
                if cell.status == .today {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.colors.accentInk.color)
                } else if cell.status == .overBudget {
                    Circle()
                        .fill(theme.colors.textTertiary.color)
                        .frame(width: 5, height: 5)
                }
            }
            .shadow(
                color: cell.status == .today ? theme.colors.accent.color.opacity(0.24) : .clear,
                radius: 6,
                x: 0,
                y: 3
            )
            .accessibilityLabel(cell.status.displayLabel)
    }

    private var fillColor: Color {
        switch cell.status {
        case .unknown:
            return theme.colors.surface.color.opacity(0.55)
        case .underBudget, .today:
            return theme.colors.accent.color
        case .overBudget:
            return theme.colors.surfaceMuted.color
        }
    }

    private var borderColor: Color {
        switch cell.status {
        case .today:
            return theme.colors.accentPressed.color
        case .underBudget:
            return theme.colors.accent.color.opacity(0.35)
        default:
            return theme.colors.line.color
        }
    }

    private var borderWidth: CGFloat {
        cell.status == .today ? 3 : theme.metrics.borderWidth
    }
}

private struct StreakLegend: View {
    let color: Color
    let label: String
    var outlined = false
    var showsDot = false

    @Environment(\.babloTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 13, height: 13)
                .overlay {
                    if outlined {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.colors.line.color, lineWidth: theme.metrics.borderWidth)
                    }
                }
                .overlay {
                    if showsDot {
                        Circle()
                            .fill(theme.colors.textTertiary.color)
                            .frame(width: 4, height: 4)
                    }
                }

            Text(label)
                .font(theme.typography.body(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textTertiary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private struct StreakMilestoneCard: View {
    let milestone: StreakDetailMilestone

    @Environment(\.babloTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(milestone.day)")
                        .font(theme.typography.display(size: 28, weight: .black))
                        .monospacedDigit()

                    Text("d")
                        .font(theme.typography.body(size: 13, weight: .black))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .overlay {
                            Circle()
                                .stroke(iconBorder, lineWidth: theme.metrics.borderWidth)
                        }

                    Image(systemName: milestone.isReached ? "checkmark" : "flame")
                        .font(.system(size: 13, weight: .black))
                }
                .frame(width: 28, height: 28)
            }

            Text(milestone.title)
                .font(theme.typography.body(size: 15, weight: .black))
                .foregroundStyle(titleColor)
                .lineLimit(3)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .foregroundStyle(titleColor)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: theme.metrics.borderWidth)
        }
        .shadow(
            color: milestone.isFeatured ? theme.colors.accent.color.opacity(0.22) : .clear,
            radius: 14,
            x: 0,
            y: 8
        )
        .opacity(milestone.isReached || milestone.isFeatured ? 1 : 0.62)
    }

    private var cardBackground: Color {
        milestone.isFeatured ? theme.colors.accent.color : theme.colors.surface.color
    }

    private var cardBorder: Color {
        milestone.isFeatured ? theme.colors.accent.color : theme.colors.line.color
    }

    private var titleColor: Color {
        milestone.isFeatured ? theme.colors.accentInk.color : theme.colors.textPrimary.color
    }

    private var iconBackground: Color {
        if milestone.isReached {
            return milestone.isFeatured ? Color.white.opacity(0.35) : theme.colors.accent.color
        }
        return theme.colors.surfaceMuted.color
    }

    private var iconBorder: Color {
        milestone.isReached ? .clear : theme.colors.line.color
    }
}

// MARK: - Previews

struct StreakWidgetPreviewWrapper: View {
    let theme: BabloTheme
    let isEmpty: Bool
    let streakService: StreakService

    init(theme: BabloTheme, isEmpty: Bool) {
        self.theme = theme
        self.isEmpty = isEmpty
        self.streakService = StreakService()
        
        if !isEmpty {
            // Seed a realistic under-budget streak matching the mock image
            self.streakService.userStreak = UserStreak(
                currentStreak: 7,
                maxStreak: 12,
                last10DaysStatus: [true, true, true, true, true, false, false, false, false, false]
            )
        }
    }

    var body: some View {
        StreakWidgetView()
            .environmentObject(streakService)
            .babloTheme(theme)
            .frame(width: 170)
            .padding()
            .background(theme == .pop ? Color(hex: "#FFF09A") : Color(hex: "#F8F5EF"))
    }
}

#Preview("Streak Normal Regular") {
    StreakWidgetPreviewWrapper(theme: .normal, isEmpty: false)
}

#Preview("Streak Pop Regular") {
    StreakWidgetPreviewWrapper(theme: .pop, isEmpty: false)
}

#Preview("Streak Normal Empty") {
    StreakWidgetPreviewWrapper(theme: .normal, isEmpty: true)
}

#Preview("Streak Pop Empty") {
    StreakWidgetPreviewWrapper(theme: .pop, isEmpty: true)
}
