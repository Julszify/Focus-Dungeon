// Plays focus sessions in the terminal to try out and balance the game logic.
//
//   swift run dungeon-demo [--minutes 25] [--category work] [--sessions 1] [--abort-at N] [--seed 42]
//
// Categories: learning, work, sport, creative

import DungeonCore
import Foundation

var minutes = 25
var category = FocusCategory.work
var sessions = 1
var abortAt: Int?
var seed: UInt64 = 42

var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    let value = args.next() ?? ""
    switch arg {
    case "--minutes": minutes = Int(value) ?? minutes
    case "--category": category = FocusCategory(rawValue: value) ?? category
    case "--sessions": sessions = Int(value) ?? sessions
    case "--abort-at": abortAt = Int(value)
    case "--seed": seed = UInt64(value) ?? seed
    default:
        print("Unbekannte Option: \(arg)")
        exit(1)
    }
}

func describe(_ hero: Hero) -> String {
    let s = hero.stats
    let gear = ItemSlot.allCases.map { "\($0.displayName): \(hero.equipped(in: $0)?.name ?? "–")" }.joined(separator: ", ")
    return """
    🧙 \(hero.name), Stufe \(hero.level) \(hero.heroClass.displayName)  (XP \(hero.xp)/\(Hero.xpNeeded(forLevel: hero.level)), \(hero.gold) Gold, Start: Ebene \(hero.checkpointFloor))
       INT \(s.intelligence)  GES \(s.dexterity)  STÄ \(s.strength)  CHA \(s.charisma)  |  HP \(hero.maxHP)  ANG \(hero.attack)  VER \(hero.defense)
       \(gear)
    """
}

let icons: [DungeonEventKind: String] = [
    .fight: "⚔️ ", .bossFight: "👑", .treasure: "💰", .loot: "🎁", .trap: "🪤",
    .shrine: "✨", .quiet: "🕯️", .knockout: "💫", .descend: "🪜",
]

var hero = Hero(name: "Ari")
print(describe(hero))

let start = Date(timeIntervalSince1970: 0)
for number in 1...sessions {
    var session = FocusSession(category: category, plannedMinutes: minutes, startDate: start, seed: seed &+ UInt64(number))
    let end: Date
    if let abortAt {
        end = start.addingTimeInterval(TimeInterval(abortAt * 60))
        session.abandon(at: end)
    } else {
        end = session.plannedEndDate
    }

    let report = Adventure.finish(session, hero: &hero, at: end)

    print("\n━━━ Session \(number): \(category.emoji) \(category.displayName), \(report.focusedMinutes)/\(minutes) Min. ━━━")
    for event in report.events {
        let hp = "[\(event.hpAfter)/\(event.maxHP) HP]".padding(toLength: 13, withPad: " ", startingAt: 0)
        print(" \(String(format: "%3d", event.minute))' \(hp) \(icons[event.kind] ?? "") \(event.text)")
    }
    print("""

    📜 Abenteuerbericht: \(report.outcome == .completed ? "Erfolgreich zurückgekehrt!" : "Geflohen! Die Hälfte des Goldes und alle Fundstücke sind verloren.")
       Ebene \(report.floorReached) · \(report.monstersDefeated) Gegner (\(report.bossesDefeated) Bosse) · +\(report.gold) Gold · +\(report.xp) XP · \(report.items.count) Gegenstände
       \(report.stat.displayName) +\(report.statGain)\(report.levelsGained > 0 ? " · ⬆️ \(report.levelsGained) Stufe(n) aufgestiegen" : "")

    """)
    print(describe(hero))
}
