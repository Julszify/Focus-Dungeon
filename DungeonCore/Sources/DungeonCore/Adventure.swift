import Foundation

public struct AdventureReport: Codable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case completed, fled
    }

    public let outcome: Outcome
    public let category: FocusCategory
    public let plannedMinutes: Int
    public let focusedMinutes: Int
    public let events: [DungeonEvent]
    public let floorReached: Int
    public let monstersDefeated: Int
    public let bossesDefeated: Int
    public let gold: Int
    public let xp: Int
    public let items: [Item]
    public let levelsGained: Int
    public let statGain: Int

    public var stat: StatKind { category.stat }
}

/// Ties a focus session to the dungeon: preview it live, then settle it onto the hero.
public enum Adventure {
    /// The run for a session in progress. `hero` must be the hero as it was at session start.
    public static func run(for session: FocusSession, hero: Hero) -> DungeonRun {
        DungeonSimulator.simulate(hero: hero, minutes: session.plannedMinutes, seed: session.seed)
    }

    /// Settles a finished session: applies loot, XP and stat training to the hero.
    /// A session that is still running is treated as abandoned now.
    public static func finish(_ session: FocusSession, hero: inout Hero, at now: Date = .now) -> AdventureReport {
        var session = session
        session.update(at: now)
        session.abandon(at: now)

        let completed = session.state == .completed
        let minutes = session.focusedMinutes(at: now)
        let events = run(for: session, hero: hero).events(upToMinute: minutes)

        let earnedGold = events.reduce(0) { $0 + $1.gold }
        let xp = events.reduce(0) { $0 + $1.xp }
        // Fleeing keeps the experience, but half the gold and none of the items.
        let gold = completed ? earnedGold : max(0, earnedGold) / 2
        let items = completed ? events.compactMap(\.item) : []
        let statGain = completed ? max(1, minutes / 10) : minutes / 20

        let levelsGained = hero.gainXP(xp)
        hero.gold += gold
        hero.stats[session.category.stat] += statGain
        hero.totalFocusMinutes += minutes
        items.forEach { hero.receive($0) }
        if let deepestBoss = events.last(where: { $0.kind == .bossFight })?.floor {
            hero.checkpointFloor = max(hero.checkpointFloor, deepestBoss + 1)
        }

        return AdventureReport(
            outcome: completed ? .completed : .fled,
            category: session.category,
            plannedMinutes: session.plannedMinutes,
            focusedMinutes: minutes,
            events: events,
            floorReached: events.last?.floor ?? 0,
            monstersDefeated: events.filter { $0.kind == .fight || $0.kind == .bossFight }.count,
            bossesDefeated: events.filter { $0.kind == .bossFight }.count,
            gold: gold,
            xp: xp,
            items: items,
            levelsGained: levelsGained,
            statGain: statGain
        )
    }
}
