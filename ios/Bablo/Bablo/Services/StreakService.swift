//
//  StreakService.swift
//  Bablo
//

import Foundation
import Supabase

enum StreakCalendarDayStatus: Equatable {
    case unknown
    case underBudget
    case overBudget
    case today

    var displayLabel: String {
        switch self {
        case .unknown:
            return "No data"
        case .underBudget:
            return "Under budget"
        case .overBudget:
            return "Over budget"
        case .today:
            return "Today under budget"
        }
    }
}

struct StreakCalendarCell: Identifiable, Equatable {
    let id: Int
    let status: StreakCalendarDayStatus
    let date: Date
}

struct StreakDetailMilestone: Identifiable, Equatable {
    var id: Int { day }
    let day: Int
    let title: String
    let isReached: Bool
    let isFeatured: Bool
}

extension UserStreak {
    static let streakMilestoneDays = [3, 7, 14, 30, 60]

    var nextMilestoneDay: Int {
        Self.streakMilestoneDays.first(where: { $0 > currentStreak }) ?? Self.streakMilestoneDays.last ?? 60
    }

    var daysToNextMilestone: Int {
        max(nextMilestoneDay - currentStreak, 0)
    }

    var milestoneProgress: Double {
        guard nextMilestoneDay > 0 else { return 1 }
        return min(max(Double(currentStreak) / Double(nextMilestoneDay), 0), 1)
    }

    var earnedFreezeCount: Int {
        min(max(currentStreak / 3, 0), 3)
    }

    var freezeMarkerSummary: String {
        "Earned every 3 under-budget days. They are streak checkpoints, not extra spending money."
    }

    var detailMilestones: [StreakDetailMilestone] {
        Self.streakMilestoneDays.map { day in
            StreakDetailMilestone(
                day: day,
                title: milestoneTitle(for: day),
                isReached: currentStreak >= day,
                isFeatured: featuredMilestoneDay == day
            )
        }
    }

    var detailCalendarCells: [StreakCalendarCell] {
        let cal = Calendar.bablo
        let today = Date()
        
        let chronologicalStatuses = Array(last10DaysStatus.prefix(10)).reversed()
        let knownCells = chronologicalStatuses.enumerated().map { index, isUnderBudget in
            let isToday = index == chronologicalStatuses.count - 1
            let status: StreakCalendarDayStatus

            if isToday && isUnderBudget {
                status = .today
            } else {
                status = isUnderBudget ? .underBudget : .overBudget
            }

            let daysAgo = chronologicalStatuses.count - 1 - index
            let cellDate = cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today

            return StreakCalendarCell(id: 35 - chronologicalStatuses.count + index, status: status, date: cellDate)
        }

        let unknownCount = max(35 - knownCells.count, 0)
        let unknownCells = (0..<unknownCount).map { index in
            let daysAgo = 35 - 1 - index
            let cellDate = cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return StreakCalendarCell(id: index, status: .unknown, date: cellDate)
        }

        return unknownCells + knownCells
    }

    private var featuredMilestoneDay: Int {
        Self.streakMilestoneDays.last(where: { currentStreak >= $0 }) ?? nextMilestoneDay
    }

    private func milestoneTitle(for day: Int) -> String {
        switch day {
        case 3:
            return "Freeze marker earned"
        case 7:
            return "Personal best badge"
        case 14:
            return "14-day momentum"
        case 30:
            return "Month of discipline"
        case 60:
            return "Legend status"
        default:
            return "\(day)-day streak"
        }
    }
}

@MainActor
class StreakService: ObservableObject {
    @Published var userStreak: UserStreak? = nil
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabaseClient
    }

    /// Dynamic user streak fetch
    func fetchUserStreak() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let todayStr = PreviousPeriodDateRange.compute(calendar: .bablo).todayDate
            struct Params: Encodable {
                let p_today: String
            }
            
            let streak: [UserStreak] = try await supabase
                .rpc("get_user_spending_streak", params: Params(p_today: todayStr))
                .execute()
                .value
            
            self.userStreak = streak.first?.limitedToTrackedWindow()
            Logger.i("StreakService: Loaded streak tracker successfully: \(self.userStreak?.currentStreak ?? 0) days")
        } catch {
            Logger.e("StreakService: Failed to fetch user spending streak: \(error)")
            self.error = error
            throw error
        }
    }

    func clearStreak() {
        userStreak = nil
        error = nil
    }
}

private extension UserStreak {
    func limitedToTrackedWindow() -> UserStreak {
        UserStreak(
            currentStreak: min(max(currentStreak, 0), 90),
            maxStreak: min(max(maxStreak, 0), 90),
            last10DaysStatus: Array(last10DaysStatus.prefix(10))
        )
    }
}
