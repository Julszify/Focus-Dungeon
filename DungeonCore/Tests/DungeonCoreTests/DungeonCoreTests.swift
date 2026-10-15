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
