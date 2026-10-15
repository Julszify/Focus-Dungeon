import ActivityKit
import DungeonCore
import Foundation

/// Data for the Live Activity on the lock screen and in the Dynamic Island.
/// Shared between the app (which starts and updates it) and the widget extension (which draws it).
nonisolated struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var floor: Int
        var hp: Int
        var maxHP: Int
        var lastEvent: String
        var lastEventIcon: String
        /// Set once the session is over, for the final frame before the activity disappears.
        var outcome: String?
    }

    var heroName: String
    var heroClass: HeroClass
    var category: FocusCategory
    var startDate: Date
    var endDate: Date
    /// The boss within reach of this session, if any.
    var bossName: String?
    var bossFloor: Int?

    var timerRange: ClosedRange<Date> { startDate...endDate }
}
