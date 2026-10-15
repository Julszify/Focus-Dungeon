import ActivityKit
import DungeonCore
import Foundation

/// Starts, updates and ends the Live Activity for the running session.
/// Updates only arrive while the app runs; countdown and progress keep ticking on their own.
final class LiveActivityController {
    private typealias State = FocusActivityAttributes.ContentState

    // Activity isn't Sendable, so only its id is kept and the activity is looked up where it's used.
    private var activityID: String?
    private var lastEventID: Int?

    init() {
        // The activity outlives the app process, so reattach after a relaunch.
        activityID = Activity<FocusActivityAttributes>.activities.first?.id
    }

    private nonisolated static func activity(withID id: String) -> Activity<FocusActivityAttributes>? {
        Activity<FocusActivityAttributes>.activities.first { $0.id == id }
    }

    func start(session: FocusSession, hero: Hero) {
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let boss = DungeonSimulator.nextBoss(from: hero.checkpointFloor)
        let bossInReach = boss.minutes <= session.plannedMinutes
        let attributes = FocusActivityAttributes(
            heroName: hero.name,
            heroClass: hero.heroClass,
            category: session.category,
            startDate: session.startDate,
            endDate: session.plannedEndDate,
            bossName: bossInReach ? boss.name : nil,
            bossFloor: bossInReach ? boss.floor : nil
        )
        let state = State(floor: hero.checkpointFloor, hp: hero.maxHP, maxHP: hero.maxHP,
                          lastEvent: "Dein Held entzündet eine Fackel und betritt den Dungeon …",
                          lastEventIcon: "🕯️", outcome: nil)
        activityID = (try? Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: session.plannedEndDate)))?.id
        lastEventID = nil
    }

    /// Shows the newest dungeon event, if it changed since the last update.
    func update(latest event: DungeonEvent?, session: FocusSession) {
        guard let id = activityID, let event, event.id != lastEventID else { return }
        lastEventID = event.id
        let state = State(floor: event.floor, hp: event.hpAfter, maxHP: event.maxHP,
                          lastEvent: event.text, lastEventIcon: event.kind.icon, outcome: nil)
        let staleDate = session.plannedEndDate
        Task.detached {
            await Self.activity(withID: id)?.update(ActivityContent(state: state, staleDate: staleDate))
        }
    }

    /// Shows the outcome briefly, then lets the activity go.
    func end(with report: AdventureReport) {
        guard let id = activityID else { return }
        activityID = nil
        let outcome = report.outcome == .completed
            ? "🏆 Zurückgekehrt von Ebene \(report.floorReached) · +\(report.gold) Gold"
            : "🏃 Geflohen nach \(report.focusedMinutes) Min."
        let state = State(floor: max(report.floorReached, 1), hp: 0, maxHP: 0,
                          lastEvent: "", lastEventIcon: "", outcome: outcome)
        Task.detached {
            await Self.activity(withID: id)?.end(ActivityContent(state: state, staleDate: nil),
                                                 dismissalPolicy: .after(.now.addingTimeInterval(10 * 60)))
        }
    }

    /// Removes leftovers, e.g. from a session that ended while the app was not running.
    func endAll() {
        activityID = nil
        // Decide now which ones to end, so an activity started right after this survives.
        let leftovers = Activity<FocusActivityAttributes>.activities.map(\.id)
        Task.detached {
            for id in leftovers {
                await Self.activity(withID: id)?.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
