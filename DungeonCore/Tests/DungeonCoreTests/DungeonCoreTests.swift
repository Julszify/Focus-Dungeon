import Foundation
import Testing
@testable import DungeonCore

private let start = Date(timeIntervalSince1970: 0)

private func minutes(_ m: Double) -> Date {
    start.addingTimeInterval(m * 60)
}

@Suite("FocusSession")
struct FocusSessionTests {
    @Test func completesAtPlannedEnd() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.update(at: minutes(24))
        #expect(session.state == .running)
        session.update(at: minutes(30))
        #expect(session.state == .completed)
        #expect(session.focusedMinutes(at: minutes(30)) == 25)
    }

    @Test func shortTripAwayIsForgiven() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.appDidLeave(at: minutes(5))
        session.appDidReturn(at: minutes(5).addingTimeInterval(FocusSession.gracePeriod - 1))
        #expect(session.state == .running)
    }

    @Test func longTripAwayAbandonsAtGraceDeadline() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.appDidLeave(at: minutes(5))
        session.appDidReturn(at: minutes(20))
        #expect(session.state == .abandoned)
        #expect(session.focusedMinutes() == 5)
    }

    @Test func lockingTheScreenIsAllowed() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.appDidLeave(at: minutes(5))
        session.screenDidLock(at: minutes(5).addingTimeInterval(12), detectionDelay: 10)
        session.appDidReturn(at: minutes(20))
        #expect(session.state == .running)
    }

    @Test func lockingAfterBeingAwayTooLongStillFlees() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.appDidLeave(at: minutes(5))
        session.screenDidLock(at: minutes(6), detectionDelay: 10)
        #expect(session.state == .abandoned)
        #expect(session.focusedMinutes() == 5)
    }

    @Test func finishingWhileAwayWithinGraceCounts() {
        var session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 1)
        session.appDidLeave(at: minutes(24.95))
        session.appDidReturn(at: minutes(40))
        #expect(session.state == .completed)
    }
}

@Suite("Dungeon")
struct DungeonTests {
    @Test func sameSeedSameRun() {
        let hero = Hero(name: "Test")
        let a = DungeonSimulator.simulate(hero: hero, minutes: 25, seed: 42)
        let b = DungeonSimulator.simulate(hero: hero, minutes: 25, seed: 42)
        #expect(a.events == b.events)
    }

    @Test func oneRoomPerMinuteAndBossAtTheEnd() {
        let run = DungeonSimulator.simulate(hero: Hero(name: "Test"), minutes: 25, seed: 42)
        let rooms = run.events.filter { $0.kind != .descend }
        #expect(rooms.count == 25)
        #expect(Set(rooms.map(\.minute)) == Set(1...25))
        let last = rooms.last!
        #expect(last.floor == 5)
        #expect(last.kind == .bossFight || last.kind == .knockout)
    }

    @Test func startsAtCheckpoint() {
        var hero = Hero(name: "Test")
        hero.checkpointFloor = 6
        let run = DungeonSimulator.simulate(hero: hero, minutes: 5, seed: 1)
        #expect(run.events.allSatisfy { $0.floor == 6 })
    }

    @Test func nextBossPreview() {
        let fromStart = DungeonSimulator.nextBoss(from: 1)
        #expect(fromStart.floor == 5)
        #expect(fromStart.minutes == 25)
        #expect(fromStart.name == "Goblinkönig")
        #expect(DungeonSimulator.nextBoss(from: 8).minutes == 15)
        #expect(DungeonSimulator.floorReached(from: 6, minutes: 25) == 10)
    }

    @Test func zeroMinutesIsEmpty() {
        #expect(DungeonSimulator.simulate(hero: Hero(name: "Test"), minutes: 0, seed: 1).events.isEmpty)
    }
}

@Suite("Adventure")
struct AdventureTests {
    @Test func completedSessionRewardsHero() {
        var hero = Hero(name: "Test")
        var session = FocusSession(category: .learning, plannedMinutes: 25, startDate: start, seed: 42)
        session.update(at: minutes(25))
        let report = Adventure.finish(session, hero: &hero, at: minutes(25))

        #expect(report.outcome == .completed)
        #expect(hero.gold == report.gold)
        #expect(hero.stats.intelligence == 1 + report.statGain)
        #expect(hero.totalFocusMinutes == 25)
        if report.bossesDefeated > 0 {
            #expect(hero.checkpointFloor == 6)
        }
    }

    @Test func fleeingKeepsHalfTheGoldAndNoItems() {
        var completedHero = Hero(name: "Test")
        var fledHero = Hero(name: "Test")
        let session = FocusSession(category: .work, plannedMinutes: 25, startDate: start, seed: 42)

        var abandoned = session
        abandoned.abandon(at: minutes(15))
        let fled = Adventure.finish(abandoned, hero: &fledHero, at: minutes(15))
        let earned = fled.events.reduce(0) { $0 + $1.gold }

        #expect(fled.outcome == .fled)
        #expect(fled.focusedMinutes == 15)
        #expect(fled.items.isEmpty)
        #expect(fled.gold == max(0, earned) / 2)
        #expect(fledHero.inventory.isEmpty)

        var completed = session
        completed.update(at: minutes(25))
        _ = Adventure.finish(completed, hero: &completedHero, at: minutes(25))
        #expect(completedHero.totalFocusMinutes > fledHero.totalFocusMinutes)
    }
}

@Suite("Hero")
struct HeroTests {
    @Test func levelsUpAcrossMultipleLevels() {
        var hero = Hero(name: "Test")
        let gained = hero.gainXP(100 + 200 + 50)
        #expect(gained == 2)
        #expect(hero.level == 3)
        #expect(hero.xp == 50)
    }

    @Test func equippingSwapsOldItemIntoInventory() {
        var hero = Hero(name: "Test")
        let old = Item(name: "Alt", slot: .weapon, rarity: .common, power: 1)
        let new = Item(name: "Neu", slot: .weapon, rarity: .rare, power: 5)
        hero.receive(old)
        hero.receive(new)
        #expect(hero.weapon == new)
        #expect(hero.inventory == [old])
    }

    @Test func classFollowsDominantStat() {
        #expect(Hero(name: "T").heroClass == .adventurer)
        #expect(Hero(name: "T", stats: Stats(intelligence: 5)).heroClass == .mage)
    }
}

@Suite("Market")
struct MarketTests {
    private func richHero() -> Hero {
        var hero = Hero(name: "Test")
        hero.gold = 10_000
        return hero
    }

    @Test func buyingPotionsCostsGoldAndStopsAtTheLimit() throws {
        var hero = richHero()
        let price = Market.potionPrice(for: hero)
        try hero.buyPotion()
        #expect(hero.potions == 1)
        #expect(hero.gold == 10_000 - price)
        for _ in 1..<Market.maxPotions { try hero.buyPotion() }
        #expect(throws: MarketError.potionsFull) { try hero.buyPotion() }
    }

    @Test func notEnoughGoldChangesNothing() {
        var hero = Hero(name: "Test")
        #expect(throws: MarketError.notEnoughGold) { try hero.buyPotion() }
        #expect(hero.potions == 0)
        #expect(hero.gold == 0)
    }

    @Test func upgradingAnEquippedItemRaisesItsPower() throws {
        var hero = richHero()
        let sword = Item(name: "Schwert", slot: .weapon, rarity: .rare, power: 5)
        hero.receive(sword)
        let attackBefore = hero.attack
        let upgraded = try hero.upgrade(itemID: sword.id)
        #expect(upgraded.upgrades == 1)
        #expect(upgraded.displayName == "Schwert +1")
        #expect(hero.weapon == upgraded)
        #expect(hero.attack == attackBefore + Market.upgradeGain(for: sword))
    }

    @Test func upgradesStopAtTheMaximum() throws {
        var hero = richHero()
        hero.gold = 10_000_000
        let ring = Item(name: "Ring", slot: .trinket, rarity: .common, power: 1)
        hero.receive(ring)
        for _ in 0..<Market.maxUpgrades { try hero.upgrade(itemID: ring.id) }
        #expect(throws: MarketError.fullyUpgraded) { try hero.upgrade(itemID: ring.id) }
    }

    @Test func sellingOnlyWorksFromTheBackpack() throws {
        var hero = Hero(name: "Test")
        let good = Item(name: "Gut", slot: .armor, rarity: .epic, power: 9)
        let old = Item(name: "Alt", slot: .armor, rarity: .common, power: 1)
        hero.receive(good)
        hero.receive(old)  // Worse, so it stays in the backpack.
        #expect(throws: MarketError.itemNotFound) { try hero.sell(itemID: good.id) }
        let value = try hero.sell(itemID: old.id)
        #expect(value == Market.sellValue(of: old))
        #expect(hero.gold == value)
        #expect(hero.inventory.isEmpty)
    }

    @Test func chestLootLandsWithTheHero() throws {
        var hero = richHero()
        let item = try hero.buyChest(seed: 7)
        #expect(hero.item(withID: item.id) != nil)
    }
}

@Suite("Potions")
struct PotionTests {
    /// A weak hero deep in the dungeon, where knockouts are certain.
    private func doomedHero(potions: Int) -> Hero {
        var hero = Hero(name: "Test")
        hero.checkpointFloor = 30
        hero.potions = potions
        return hero
    }

    @Test func potionsAreDrunkInsteadOfGoingDown() {
        let run = DungeonSimulator.simulate(hero: doomedHero(potions: 2), minutes: 10, seed: 3)
        #expect(run.events.reduce(0) { $0 + $1.potionsUsed } == 2)
    }

    @Test func finishingUsesUpThePotions() {
        var hero = doomedHero(potions: 2)
        var session = FocusSession(category: .sport, plannedMinutes: 10, startDate: start, seed: 3)
        session.update(at: minutes(10))
        let report = Adventure.finish(session, hero: &hero, at: minutes(10))
        #expect(report.potionsUsed == 2)
        #expect(hero.potions == 0)
    }
}

@Suite("Save game compatibility")
struct CompatibilityTests {
    @Test func heroFromTheFirstVersionStillLoads() throws {
        // A hero as saved before potions and forge upgrades existed.
        let json = """
        {"name":"Ari","level":3,"xp":40,"gold":250,"totalFocusMinutes":75,"checkpointFloor":6,
         "stats":{"intelligence":4,"dexterity":2,"strength":1,"charisma":1},
         "inventory":[{"id":"6E1A1F4C-0000-4000-8000-000000000001","name":"Kettenhemd","slot":"armor","rarity":1,"power":4}],
         "weapon":{"id":"6E1A1F4C-0000-4000-8000-000000000002","name":"Eichenstab","slot":"weapon","rarity":2,"power":6}}
        """
        let hero = try JSONDecoder().decode(Hero.self, from: Data(json.utf8))
        #expect(hero.level == 3)
        #expect(hero.potions == 0)
        #expect(hero.weapon?.upgrades == 0)
        #expect(hero.inventory.first?.name == "Kettenhemd")
        #expect(hero.armor == nil)
    }

    @Test func eventFromAnOlderReportStillLoads() throws {
        let json = #"{"id":0,"minute":1,"floor":1,"kind":"fight","text":"Ratte besiegt.","hpAfter":20,"maxHP":31,"gold":3,"xp":12}"#
        let event = try JSONDecoder().decode(DungeonEvent.self, from: Data(json.utf8))
        #expect(event.monster == nil)
        #expect(event.potionsUsed == 0)
    }

    @Test func fightsRememberTheirMonster() {
        let run = DungeonSimulator.simulate(hero: Hero(name: "Test"), minutes: 25, seed: 42)
        let fights = run.events.filter { [.fight, .bossFight, .knockout].contains($0.kind) }
        #expect(!fights.isEmpty)
        #expect(fights.allSatisfy { $0.monster != nil })
        #expect(run.events.filter { $0.kind == .treasure }.allSatisfy { $0.monster == nil })
    }

    @Test func roundTripKeepsNewFields() throws {
        var hero = Hero(name: "Test")
        hero.gold = 1_000
        hero.receive(Item(name: "Dolch", slot: .weapon, rarity: .uncommon, power: 3))
        try hero.buyPotion()
        try hero.upgrade(itemID: hero.weapon!.id)
        let copy = try JSONDecoder().decode(Hero.self, from: JSONEncoder().encode(hero))
        #expect(copy.potions == 1)
        #expect(copy.weapon?.upgrades == 1)
    }
}

@Suite("Chronicle")
struct ChronicleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Noon on day `n` after the reference date, in UTC.
    private func day(_ n: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSince1970: TimeInterval(n * 86_400 + hour * 3_600))
    }

    private func record(day n: Int, minutes: Int, category: FocusCategory = .work, completed: Bool = true,
                        floor: Int = 1, bosses: Int = 0) -> SessionRecord {
        let report = AdventureReport(outcome: completed ? .completed : .fled, category: category,
                                     plannedMinutes: minutes, focusedMinutes: minutes, events: [],
                                     floorReached: floor, monstersDefeated: 0, bossesDefeated: bosses,
                                     gold: 0, xp: 0, items: [], levelsGained: 0, statGain: 0, potionsUsed: 0)
        return SessionRecord(report: report, date: day(n))
    }

    @Test func totalsAndRecords() {
        let chronicle = Chronicle(records: [
            record(day: 0, minutes: 25, floor: 5, bosses: 1),
            record(day: 1, minutes: 45, category: .learning, floor: 9),
            record(day: 1, minutes: 7, completed: false),
        ], calendar: calendar)
        #expect(chronicle.totalMinutes == 77)
        #expect(chronicle.completedCount == 2)
        #expect(chronicle.fledCount == 1)
        #expect(chronicle.bossesDefeated == 1)
        #expect(chronicle.deepestFloor == 9)
        #expect(chronicle.longestSession?.focusedMinutes == 45)
        #expect(chronicle.minutes(in: .work) == 32)
    }

    @Test func dailyCoversEveryDayAndCategory() {
        let chronicle = Chronicle(records: [record(day: 5, minutes: 25), record(day: 5, minutes: 15, category: .sport)],
                                  calendar: calendar)
        let daily = chronicle.daily(days: 7, endingOn: day(6))
        #expect(daily.count == 7 * FocusCategory.allCases.count)
        #expect(daily.filter { $0.minutes > 0 }.count == 2)
        #expect(daily.first?.day == calendar.startOfDay(for: day(0)))
    }

    @Test func streakCountsConsecutiveDaysAndForgivesAnOpenToday() {
        let chronicle = Chronicle(records: [
            record(day: 1, minutes: 25),
            record(day: 2, minutes: 25),
            record(day: 3, minutes: 5),   // Too short to count.
            record(day: 3, minutes: 6),   // Together with the one above it does.
            record(day: 5, minutes: 25),
        ], calendar: calendar)
        #expect(chronicle.currentStreak(today: day(5)) == 1)
        #expect(chronicle.currentStreak(today: day(6)) == 1)  // Nothing yet today: still alive.
        #expect(chronicle.currentStreak(today: day(7)) == 0)
        #expect(chronicle.currentStreak(today: day(3, hour: 20)) == 3)
        #expect(chronicle.longestStreak == 3)
    }
}
