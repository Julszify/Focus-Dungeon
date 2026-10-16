public struct Hero: Codable, Sendable {
    public var name: String
    public var level: Int = 1
    public var xp: Int = 0
    public var gold: Int = 0
    public var stats: Stats
    public var inventory: [Item] = []
    public var weapon: Item?
    public var armor: Item?
    public var trinket: Item?
    public var totalFocusMinutes: Int = 0
    /// Sessions start here. Defeating a boss moves the checkpoint below its floor.
    public var checkpointFloor: Int = 1
    /// Healing potions; one is drunk automatically instead of being knocked out.
    public var potions: Int = 0

    public init(name: String, stats: Stats = Stats()) {
        self.name = name
        self.stats = stats
    }

    // Fields added after the first release are optional in the save game.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        level = try container.decode(Int.self, forKey: .level)
        xp = try container.decode(Int.self, forKey: .xp)
        gold = try container.decode(Int.self, forKey: .gold)
        stats = try container.decode(Stats.self, forKey: .stats)
        inventory = try container.decode([Item].self, forKey: .inventory)
        weapon = try container.decodeIfPresent(Item.self, forKey: .weapon)
        armor = try container.decodeIfPresent(Item.self, forKey: .armor)
        trinket = try container.decodeIfPresent(Item.self, forKey: .trinket)
        totalFocusMinutes = try container.decode(Int.self, forKey: .totalFocusMinutes)
        checkpointFloor = try container.decode(Int.self, forKey: .checkpointFloor)
        potions = try container.decodeIfPresent(Int.self, forKey: .potions) ?? 0
    }

    public var heroClass: HeroClass {
        switch stats.dominant {
        case .intelligence: .mage
        case .dexterity: .rogue
        case .strength: .warrior
        case .charisma: .bard
        case nil: .adventurer
        }
    }

    // MARK: Derived combat values

    public var maxHP: Int {
        20 + level * 8 + stats.strength * 3 + (armor?.power ?? 0)
    }

    /// Uses the best of the three fighting stats, so every class can hit hard.
    public var attack: Int {
        let fightingStat = max(stats.strength, stats.dexterity, stats.intelligence)
        return 2 + level * 2 + fightingStat / 2 + (weapon?.power ?? 0)
    }

    public var defense: Int {
        (armor?.power ?? 0) + stats.dexterity / 4 + level / 2
    }

    public var critChance: Double {
        min(0.05 + Double(stats.dexterity) * 0.01, 0.5)
    }

    public var luck: Int {
        trinket?.power ?? 0
    }

    public var goldMultiplier: Double {
        1 + Double(stats.charisma) * 0.03 + Double(luck) * 0.05
    }

    // MARK: Progression

    public static func xpNeeded(forLevel level: Int) -> Int {
        100 * level
    }

    /// Adds XP and returns how many levels were gained.
    @discardableResult
    public mutating func gainXP(_ amount: Int) -> Int {
        xp += amount
        var gained = 0
        while xp >= Hero.xpNeeded(forLevel: level) {
            xp -= Hero.xpNeeded(forLevel: level)
            level += 1
            gained += 1
        }
        return gained
    }

    public func equipped(in slot: ItemSlot) -> Item? {
        switch slot {
        case .weapon: weapon
        case .armor: armor
        case .trinket: trinket
        }
    }

    /// Equips an item from the inventory; the previously equipped item goes back into it.
    public mutating func equip(_ item: Item) {
        inventory.removeAll { $0.id == item.id }
        if let old = equipped(in: item.slot) {
            inventory.append(old)
        }
        switch item.slot {
        case .weapon: weapon = item
        case .armor: armor = item
        case .trinket: trinket = item
        }
    }

    /// Adds loot to the inventory and equips it right away if it beats the current item.
    public mutating func receive(_ item: Item) {
        inventory.append(item)
        if item.power > (equipped(in: item.slot)?.power ?? 0) {
            equip(item)
        }
    }
}
