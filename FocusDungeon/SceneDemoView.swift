#if DEBUG
import DungeonCore
import SwiftUI

/// Debug-only: loops every kind of room so the scene animations can be checked without waiting
/// for a real session. Start the app with the launch argument `-sceneDemo`, or in the simulator with
/// `SIMCTL_CHILD_SCENE_DEMO=1 xcrun simctl launch booted de.wizard-labs.FocusDungeon`.
struct SceneDemoView: View {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-sceneDemo") || ProcessInfo.processInfo.environment["SCENE_DEMO"] != nil
    }

    private static let cycle = 8.0
    private static let kinds: [DungeonEventKind] = [.fight, .bossFight, .treasure, .loot, .trap, .shrine, .knockout]

    /// One real example per kind, taken from simulated runs.
    private static let examples: [DungeonEvent] = {
        var hero = Hero(name: "Demo")
        hero.checkpointFloor = 3
        var found: [DungeonEventKind: DungeonEvent] = [:]
        for seed in UInt64(1)...400 where found.count < kinds.count {
            hero.checkpointFloor = seed.isMultiple(of: 2) ? 3 : 24  // Deep runs for knockouts.
            for event in DungeonSimulator.simulate(hero: hero, minutes: 25, seed: seed).events
            where kinds.contains(event.kind) && found[event.kind] == nil {
                found[event.kind] = event
            }
        }
        return kinds.compactMap { found[$0] }
    }()

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: Self.cycle)) { context in
            let index = Int(context.date.timeIntervalSince1970 / Self.cycle) % max(Self.examples.count, 1)
            let event = Self.examples[index]
            let cycleStart = Date(timeIntervalSince1970: (context.date.timeIntervalSince1970 / Self.cycle).rounded(.down) * Self.cycle)
            // A session that reaches this event's room right when the cycle starts.
            let session = FocusSession(category: .work, plannedMinutes: event.minute + 5,
                                       startDate: cycleStart.addingTimeInterval(-Double(event.minute * 60) + 0.5), seed: 0)
            VStack(spacing: 16) {
                Text("Szenen-Vorschau: \(event.kind.rawValue)").font(Theme.title(16))
                DungeonScene(session: session, events: [event], heroClass: .warrior, startHP: event.maxHP)
                    .frame(height: 250)
                Text(event.text).font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
        .background(Theme.background)
    }
}
#endif
