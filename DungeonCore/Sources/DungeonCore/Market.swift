/// Prices and rules of the tavern market: merchant, forge and selling.
public enum Market {
    public static let maxPotions = 5
    public static let maxUpgrades = 10

    public static func potionPrice(for hero: Hero) -> Int {
        20 + hero.level * 10
    }

    /// Chests get pricier, and their loot better, the deeper the hero's checkpoint.
    public static func chestPrice(for hero: Hero) -> Int {
        80 + hero.checkpointFloor * 25
    }

    /// Nil once the item is fully upgraded.
    public static func upgradeCost(for item: Item) -> Int? {
        guard item.upgrades < maxUpgrades else { return nil }
        return (10 + item.power * 8) * (item.upgrades + 1)
    }

    /// Rarer items gain more per upgrade, so they're worth investing in.
    public static func upgradeGain(for item: Item) -> Int {
        1 + item.rarity.rawValue / 2
    }

    public static func sellValue(of item: Item) -> Int {
        5 + item.power * 3 + item.rarity.rawValue * 10
    }
}

public enum MarketError: Error, Equatable {
    case notEnoughGold, potionsFull, fullyUpgraded, itemNotFound
}

extension Hero {
    public mutating func buyPotion() throws(MarketError) {
        guard potions < Market.maxPotions else { throw .potionsFull }
        try pay(Market.potionPrice(for: self))
        potions += 1
    }

    /// Buys a chest and puts its item into the inventory (equipping it if better).
    @discardableResult
    public mutating func buyChest(seed: UInt64 = .random(in: 0 ... .max)) throws(MarketError) -> Item {
        try pay(Market.chestPrice(for: self))
        var rng = SeededRandom(seed: seed)
        let item = ItemCatalog.roll(floor: checkpointFloor + 3, luck: luck, rng: &rng)
        receive(item)
        return item
    }

    /// Improves an equipped or carried item and returns the upgraded version.
    @discardableResult
    public mutating func upgrade(itemID: Item.ID) throws(MarketError) -> Item {
        guard let item = item(withID: itemID) else { throw .itemNotFound }
        guard let cost = Market.upgradeCost(for: item) else { throw .fullyUpgraded }
        try pay(cost)
        var upgraded = item
        upgraded.power += Market.upgradeGain(for: item)
        upgraded.upgrades += 1
        replace(upgraded)
        return upgraded
    }

    /// Sells an item from the backpack. Equipped items have to be taken off first.
    @discardableResult
    public mutating func sell(itemID: Item.ID) throws(MarketError) -> Int {
        guard let index = inventory.firstIndex(where: { $0.id == itemID }) else { throw .itemNotFound }
        let value = Market.sellValue(of: inventory.remove(at: index))
        gold += value
        return value
    }

    public func item(withID id: Item.ID) -> Item? {
        ItemSlot.allCases.compactMap { equipped(in: $0) }.first { $0.id == id }
            ?? inventory.first { $0.id == id }
    }

    private mutating func pay(_ price: Int) throws(MarketError) {
        guard gold >= price else { throw .notEnoughGold }
        gold -= price
    }

    private mutating func replace(_ item: Item) {
        if weapon?.id == item.id { weapon = item }
        if armor?.id == item.id { armor = item }
        if trinket?.id == item.id { trinket = item }
        if let index = inventory.firstIndex(where: { $0.id == item.id }) { inventory[index] = item }
    }
}
