import Foundation

/// One finished focus session, as kept in the hero's chronicle.
public struct SessionRecord: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let category: FocusCategory
    public let plannedMinutes: Int
    public let focusedMinutes: Int
    public let completed: Bool
    public let floorReached: Int
    public let bossesDefeated: Int
    public let gold: Int

    public init(report: AdventureReport, date: Date, id: UUID = UUID()) {
        self.id = id
        self.date = date
        category = report.category
        plannedMinutes = report.plannedMinutes
        focusedMinutes = report.focusedMinutes
        completed = report.outcome == .completed
        floorReached = report.floorReached
        bossesDefeated = report.bossesDefeated
        gold = report.gold
    }
}

/// Focus minutes of one category on one day, e.g. for a stacked bar chart.
public struct DailyFocus: Hashable, Sendable, Identifiable {
    public let day: Date
    public let category: FocusCategory
    public let minutes: Int
    public var id: String { "\(day.timeIntervalSince1970)-\(category.rawValue)" }
}

/// Statistics over the recorded sessions.
public struct Chronicle: Sendable {
    /// A day counts towards the streak with at least this much focus.
    public static let streakMinutes = 10

    public let records: [SessionRecord]
    private let calendar: Calendar

    public init(records: [SessionRecord], calendar: Calendar = .current) {
        self.records = records.sorted { $0.date > $1.date }
        self.calendar = calendar
    }

    public var totalMinutes: Int { records.reduce(0) { $0 + $1.focusedMinutes } }
    public var completedCount: Int { records.filter(\.completed).count }
    public var fledCount: Int { records.count - completedCount }
    public var bossesDefeated: Int { records.reduce(0) { $0 + $1.bossesDefeated } }
    public var deepestFloor: Int { records.map(\.floorReached).max() ?? 0 }
    public var longestSession: SessionRecord? { records.max { $0.focusedMinutes < $1.focusedMinutes } }

    public func minutes(in category: FocusCategory) -> Int {
        records.filter { $0.category == category }.reduce(0) { $0 + $1.focusedMinutes }
    }

    /// Minutes per day and category for the last `days` days up to `today`, with zero entries for quiet days.
    public func daily(days: Int = 7, endingOn today: Date = .now) -> [DailyFocus] {
        let lastDay = calendar.startOfDay(for: today)
        return (0..<days).reversed().flatMap { offset -> [DailyFocus] in
            let day = calendar.date(byAdding: .day, value: -offset, to: lastDay)!
            let sessions = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return FocusCategory.allCases.map { category in
                DailyFocus(day: day, category: category,
                           minutes: sessions.filter { $0.category == category }.reduce(0) { $0 + $1.focusedMinutes })
            }
        }
    }

    /// Days in a row with enough focus. Today still counts as open: without focus today,
    /// a streak running until yesterday is kept.
    public func currentStreak(today: Date = .now) -> Int {
        let days = focusDays
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    public var longestStreak: Int {
        var longest = 0
        var current = 0
        var previous: Date?
        for day in focusDays.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }

    private var focusDays: Set<Date> {
        let perDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        return Set(perDay.filter { $0.value.reduce(0) { $0 + $1.focusedMinutes } >= Self.streakMinutes }.keys)
    }
}
