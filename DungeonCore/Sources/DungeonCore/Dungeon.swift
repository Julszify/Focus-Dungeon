public enum DungeonEventKind: String, Codable, Sendable {
    case fight, bossFight, treasure, loot, trap, shrine, quiet, knockout, descend
}

public struct DungeonEvent: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// The focus minute at which this event happens (one room per minute).
    public let minute: Int
    public let floor: Int
    public let kind: DungeonEventKind
    public let text: String
    public let hpAfter: Int
    public let maxHP: Int
    /// Negative when gold is lost.
    public let gold: Int
    public let xp: Int
    public let item: Item?
    public let potionsUsed: Int
    /// The monster fought in this room, for drawing it.
    public let monster: String?
}

extension DungeonEvent {
    // Saved reports from earlier versions lack the newer fields.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        minute = try container.decode(Int.self, forKey: .minute)
        floor = try container.decode(Int.self, forKey: .floor)
        kind = try container.decode(DungeonEventKind.self, forKey: .kind)
        text = try container.decode(String.self, forKey: .text)
        hpAfter = try container.decode(Int.self, forKey: .hpAfter)
        maxHP = try container.decode(Int.self, forKey: .maxHP)
        gold = try container.decode(Int.self, forKey: .gold)
        xp = try container.decode(Int.self, forKey: .xp)
        item = try container.decodeIfPresent(Item.self, forKey: .item)
        potionsUsed = try container.decodeIfPresent(Int.self, forKey: .potionsUsed) ?? 0
        monster = try container.decodeIfPresent(String.self, forKey: .monster)
    }
}

public struct DungeonRun: Codable, Sendable {
    public let plannedMinutes: Int
    public let events: [DungeonEvent]

    /// What the hero has experienced after `minute` minutes of focus.
    public func events(upToMinute minute: Int) -> [DungeonEvent] {
        events.filter { $0.minute <= minute }
    }
}

struct Monster {
    let name: String
    let hp: Int
    let attack: Int
    let xp: Int
    let gold: Int
}

enum Bestiary {
    private static let tiers: [[String]] = [
        ["Ratte", "Schleim", "Goblin", "Fledermaus", "Skelett"],
        ["Ork", "Riesenspinne", "Zombie-Ritter", "Kobold-Schamane"],
        ["Troll", "Steingolem", "Vampir", "Basilisk"],
        ["Schattenwandler", "Knochendrache", "Dämonenfürst"],
    ]

    private static let bosses = [
        "Goblinkönig", "Spinnenkönigin", "Lich der Prokrastination", "Drache der Ablenkung",
    ]

    static func monster(floor: Int, rng: inout SeededRandom) -> Monster {
        let tier = min((floor - 1) / 5, tiers.count - 1)
        return Monster(
            name: rng.pick(tiers[tier]),
            hp: 6 + floor * 3 + Int.random(in: 0...floor, using: &rng),
            attack: 1 + floor,
            xp: 8 + floor * 4,
            gold: 2 + floor * 2 + Int.random(in: 0...floor, using: &rng)
        )
    }

    static func isBoss(named name: String) -> Bool {
        bosses.contains(name) || name.hasPrefix("Uralter Schatten")
    }

    static func bossName(floor: Int) -> String {
        let number = floor / DungeonSimulator.floorsPerBoss
        return number <= bosses.count ? bosses[number - 1] : "Uralter Schatten Nr. \(number - bosses.count)"
    }

    static func boss(floor: Int, rng: inout SeededRandom) -> Monster {
        let base = monster(floor: floor, rng: &rng)
        return Monster(name: bossName(floor: floor), hp: base.hp * 3, attack: base.attack + floor / 2 + 2, xp: base.xp * 5, gold: base.gold * 5)
    }
}

public enum DungeonSimulator {
    public static let roomsPerFloor = 5
    public static let floorsPerBoss = 5

    public static func isBoss(named name: String) -> Bool {
        Bestiary.isBoss(named: name)
    }

    public static func isBossFloor(_ floor: Int) -> Bool {
        floor % floorsPerBoss == 0
    }

    /// The deepest floor a session of this length reaches.
    public static func floorReached(from checkpoint: Int, minutes: Int) -> Int {
        checkpoint + max(0, minutes - 1) / roomsPerFloor
    }

    /// The next boss below the checkpoint and how many focus minutes it takes to face it.
    public static func nextBoss(from checkpoint: Int) -> (name: String, floor: Int, minutes: Int) {
        let floor = (checkpoint + floorsPerBoss - 1) / floorsPerBoss * floorsPerBoss
        return (Bestiary.bossName(floor: floor), floor, (floor - checkpoint + 1) * roomsPerFloor)
    }

    /// Precomputes the whole run, starting at the hero's checkpoint.
    /// Same hero + minutes + seed always gives the same run.
    public static func simulate(hero startHero: Hero, minutes: Int, seed: UInt64) -> DungeonRun {
        var rng = SeededRandom(seed: seed)
        // Working copy: levels up and wears loot mid-run, so later rooms reflect it.
        var hero = startHero
        var hp = hero.maxHP
        var runGold = 0
        var events: [DungeonEvent] = []

        func log(_ minute: Int, _ floor: Int, _ kind: DungeonEventKind, _ text: String,
                 gold: Int = 0, xp: Int = 0, item: Item? = nil, potionsUsed: Int = 0, monster: String? = nil) {
            runGold += gold
            events.append(DungeonEvent(id: events.count, minute: minute, floor: floor, kind: kind, text: text,
                                       hpAfter: hp, maxHP: hero.maxHP, gold: gold, xp: xp, item: item,
                                       potionsUsed: potionsUsed, monster: monster))
        }

        func scaledGold(_ base: Int) -> Int {
            Int((Double(base) * hero.goldMultiplier).rounded())
        }

        func fight(_ monster: Monster, minute: Int, floor: Int, isBoss: Bool) {
            var monsterHP = monster.hp
            var rounds = 0
            var potionsUsed = 0
            while monsterHP > 0, hp > 0, rounds < 30 {
                rounds += 1
                var damage = max(1, hero.attack + Int.random(in: -1...1, using: &rng))
                if rng.chance(hero.critChance) { damage *= 2 }
                monsterHP -= damage
                if monsterHP <= 0 { break }
                hp -= max(1, monster.attack - hero.defense + Int.random(in: -1...1, using: &rng))
                // A potion is drunk automatically instead of going down.
                if hp <= 0, hero.potions > 0 {
                    hero.potions -= 1
                    potionsUsed += 1
                    hp = hero.maxHP
                }
            }
            let potionText = potionsUsed == 0 ? "" : " 🧪 Heiltrank getrunken\(potionsUsed > 1 ? " (×\(potionsUsed))" : "")!"

            // Running out of rounds means the hero is exhausted: same as being knocked out.
            if hp <= 0 || monsterHP > 0 {
                let lost = runGold * 3 / 10
                hp = hero.maxHP / 2
                log(minute, floor, .knockout,
                    "\(monster.name) hat deinen Helden umgehauen!\(potionText) Nach einer Rast am Lagerfeuer geht es weiter, aber \(lost) Gold sind weg.",
                    gold: -lost, potionsUsed: potionsUsed, monster: monster.name)
                return
            }

            let levels = hero.gainXP(monster.xp)
            var text = isBoss
                ? "BOSS besiegt: \(monster.name)! \(rng.pick(Flavor.bossVictory))"
                : "\(monster.name) besiegt. \(rng.pick(Flavor.victory))"
            text += potionText
            if levels > 0 {
                hp = hero.maxHP
                text += " ⬆️ Stufe \(hero.level) erreicht!"
            }

            var item: Item?
            if isBoss || rng.chance(0.15 + Double(hero.luck) * 0.02) {
                let loot = ItemCatalog.roll(floor: floor + (isBoss ? 5 : 0), luck: hero.luck, rng: &rng)
                hero.receive(loot)
                item = loot
                text += " Beute: \(loot.name) (\(loot.rarity.displayName))."
            }
            log(minute, floor, isBoss ? .bossFight : .fight, text, gold: scaledGold(monster.gold), xp: monster.xp,
                item: item, potionsUsed: potionsUsed, monster: monster.name)
        }

        guard minutes > 0 else { return DungeonRun(plannedMinutes: minutes, events: []) }

        for room in 1...minutes {
            let floor = startHero.checkpointFloor + (room - 1) / roomsPerFloor
            let roomOnFloor = (room - 1) % roomsPerFloor + 1
            if room > 1, roomOnFloor == 1 {
                log(room, floor, .descend, "Eine Treppe führt hinab – Ebene \(floor).")
            }

            // The last room of every fifth floor holds its boss.
            if roomOnFloor == roomsPerFloor, isBossFloor(floor) {
                fight(Bestiary.boss(floor: floor, rng: &rng), minute: room, floor: floor, isBoss: true)
            } else {
                switch Int.random(in: 0..<100, using: &rng) {
                case ..<55:
                    fight(Bestiary.monster(floor: floor, rng: &rng), minute: room, floor: floor, isBoss: false)
                case ..<67:
                    let gold = scaledGold(5 + floor * 4 + Int.random(in: 0...(floor * 3), using: &rng))
                    log(room, floor, .treasure, "\(rng.pick(Flavor.treasure)) +\(gold) Gold.", gold: gold)
                case ..<75:
                    let loot = ItemCatalog.roll(floor: floor, luck: hero.luck, rng: &rng)
                    hero.receive(loot)
                    log(room, floor, .loot, "Eine Truhe! Darin: \(loot.name) (\(loot.rarity.displayName)).", item: loot)
                case ..<83:
                    if rng.chance(hero.critChance * 2) {
                        log(room, floor, .trap, "\(rng.pick(Flavor.trap)) Gerade noch ausgewichen!")
                    } else {
                        let damage = 2 + floor + Int.random(in: 0...floor, using: &rng)
                        hp = max(1, hp - damage)
                        log(room, floor, .trap, "\(rng.pick(Flavor.trap)) -\(damage) HP.")
                    }
                case ..<90:
                    hp = min(hero.maxHP, hp + hero.maxHP * 4 / 10)
                    log(room, floor, .shrine, rng.pick(Flavor.shrine))
                default:
                    log(room, floor, .quiet, rng.pick(Flavor.quiet))
                }
            }

            // Catching a breath between rooms.
            hp = min(hero.maxHP, hp + hero.maxHP / 10)
        }

        return DungeonRun(plannedMinutes: minutes, events: events)
    }
}

private enum Flavor {
    static let victory = [
        "Kein Problem.", "Knapp, aber geschafft.", "Mit einem eleganten Hieb.",
        "Das war fast zu einfach.", "Dein Held pustet sich lässig den Staub vom Ärmel.",
    ]
    static let bossVictory = [
        "Die Halle bebt, dann ist es still.", "Legenden werden aus solchen Momenten gemacht.",
        "Die Fokus-Macht ist stark in dir.",
    ]
    static let treasure = [
        "Ein vergessener Geldbeutel.", "Münzen glitzern zwischen den Knochen.",
        "Ein umgekippter Goldtopf.", "Jemand hat hier sein Taschengeld versteckt.",
    ]
    static let trap = [
        "Klick – eine Falltür!", "Pfeile schießen aus der Wand.",
        "Eine Bananenschale. Im Dungeon. Wirklich?", "Die Decke bröckelt.",
    ]
    static let shrine = [
        "Ein leuchtender Schrein schenkt neue Kraft.", "Eine heilende Quelle plätschert leise.",
        "Ein freundlicher Geist reicht einen Heiltrank.",
    ]
    static let quiet = [
        "Ein leerer Raum. Nur Spinnweben.", "Irgendwo tropft Wasser.",
        "Dein Held summt ein Lied, um die Stille zu füllen.", "An der Wand steht: »Hier war Kevin«.",
        "Ein Raum voller Stühle. Seltsam.",
    ]
}
