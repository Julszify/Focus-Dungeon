import Foundation

public enum ItemSlot: String, CaseIterable, Codable, Sendable {
    case weapon, armor, trinket

    public var displayName: String {
        switch self {
        case .weapon: "Waffe"
        case .armor: "Rüstung"
        case .trinket: "Talisman"
        }
    }
}

public enum Rarity: Int, CaseIterable, Codable, Comparable, Sendable {
    case common, uncommon, rare, epic, legendary

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .common: "Gewöhnlich"
        case .uncommon: "Ungewöhnlich"
        case .rare: "Selten"
        case .epic: "Episch"
        case .legendary: "Legendär"
        }
    }
}

/// `power` means attack for weapons, defense for armor and luck for trinkets.
public struct Item: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let slot: ItemSlot
    public let rarity: Rarity
    /// Includes the bonus from forge upgrades.
    public internal(set) var power: Int
    /// How often the forge has improved this item.
    public internal(set) var upgrades: Int = 0

    public init(id: UUID = UUID(), name: String, slot: ItemSlot, rarity: Rarity, power: Int) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.power = power
    }

    /// "Kettenhemd +2" once upgraded.
    public var displayName: String {
        upgrades > 0 ? "\(name) +\(upgrades)" : name
    }

    // Save games from before the forge have no `upgrades`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slot = try container.decode(ItemSlot.self, forKey: .slot)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        power = try container.decode(Int.self, forKey: .power)
        upgrades = try container.decodeIfPresent(Int.self, forKey: .upgrades) ?? 0
    }
}

enum ItemCatalog {
    private struct Template {
        let name: String
        let slot: ItemSlot
        let basePower: Int
    }

    private static let templates: [Template] = [
        Template(name: "Rostiges Kurzschwert", slot: .weapon, basePower: 1),
        Template(name: "Eichenstab", slot: .weapon, basePower: 1),
        Template(name: "Zwillingsdolche", slot: .weapon, basePower: 2),
        Template(name: "Kriegshammer", slot: .weapon, basePower: 3),
        Template(name: "Laute der Schärfe", slot: .weapon, basePower: 2),
        Template(name: "Lederwams", slot: .armor, basePower: 1),
        Template(name: "Kettenhemd", slot: .armor, basePower: 2),
        Template(name: "Robe der Ruhe", slot: .armor, basePower: 1),
        Template(name: "Plattenpanzer", slot: .armor, basePower: 3),
        Template(name: "Glückspfennig", slot: .trinket, basePower: 1),
        Template(name: "Kaffeebohnen-Amulett", slot: .trinket, basePower: 2),
        Template(name: "Ring der tiefen Konzentration", slot: .trinket, basePower: 3),
    ]

    /// Deeper floors and more luck shift the odds toward rarer items.
    static func roll(floor: Int, luck: Int, rng: inout SeededRandom) -> Item {
        let template = rng.pick(templates)
        let roll = Int.random(in: 0..<100, using: &rng) + floor * 2 + luck * 2
        let rarity: Rarity = switch roll {
        case ..<60: .common
        case ..<85: .uncommon
        case ..<100: .rare
        case ..<112: .epic
        default: .legendary
        }
        let power = template.basePower + rarity.rawValue * 2 + floor / 3
        // Derive the id from the RNG too, so re-simulating a run yields identical items.
        let id = UUID(uuid: unsafeBitCast((rng.next(), rng.next()), to: uuid_t.self))
        return Item(id: id, name: template.name, slot: template.slot, rarity: rarity, power: power)
    }
}
