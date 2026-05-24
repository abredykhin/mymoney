//
//  StreakWidgetView.swift
//  Bablo
//

import SwiftUI

struct StreakWidgetView: View {
    @EnvironmentObject var streakService: StreakService
    @Environment(\.babloTheme) private var theme

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
                        let isUnderBudget = index < statusPills.count ? statusPills[index] : false
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isUnderBudget ? theme.colors.accent.color : theme.colors.surfaceMuted.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .overlay {
                                if isPopArt {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(theme.colors.lineStrong.color, lineWidth: 1.0)
                                }
                            }
                    }
                }
                .padding(.top, 4)
            }
        }
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
