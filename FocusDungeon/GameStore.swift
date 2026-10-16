import DungeonCore
import Foundation
import Observation
import SwiftUI
import UserNotifications

/// Owns the hero and the running session, persists both, and watches whether
/// the user leaves the app mid-session.
@Observable
final class GameStore {
    private(set) var hero: Hero
    private(set) var session: FocusSession?
    /// Precomputed from the hero at session start; revealed minute by minute.
    private(set) var run: DungeonRun?
    /// Set when a session ends; cleared once the user has read it.
    private(set) var report: AdventureReport?
    /// Every finished session, for the hero's chronicle.
    private(set) var history: [SessionRecord] = []
    /// The last room of a completed session still playing out before the report.
    private(set) var finale: Finale?

    struct Finale {
        let session: FocusSession
        let events: [DungeonEvent]
        let heroClass: HeroClass
        let startHP: Int
        let until: Date
    }

    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var lockObserver: NSObjectProtocol?
    @ObservationIgnored private let liveActivity = LiveActivityController()

    private struct SaveGame: Codable {
        var hero: Hero
        var session: FocusSession?
        /// Kept until read, so it survives the app being closed right after a session.
        var report: AdventureReport?
        var history: [SessionRecord]?
    }

    private static let saveURL = URL.applicationSupportDirectory.appending(path: "savegame.json")
    private static let endNotificationID = "session-end"

    init() {
        let save = Self.loadSaveGame()
        hero = save?.hero ?? Hero(name: "Ari")
        session = save?.session
        report = save?.report
        history = save?.history ?? []
        if let session {
            run = Adventure.run(for: session, hero: hero)
        } else {
            liveActivity.endAll()
        }

        // With a passcode, protected data becomes unavailable shortly after the screen locks.
        // That tells a locked phone apart from switching to another app.
        lockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenDidLock() }
        }

        // The app may have been killed while away or while the session ran out.
        appDidReturn()
    }

    // MARK: Session lifecycle

    func startSession(category: FocusCategory, minutes: Int) {
        guard session == nil else { return }
        let newSession = FocusSession(category: category, plannedMinutes: minutes)
        session = newSession
        run = Adventure.run(for: newSession, hero: hero)
        save()
        scheduleEndNotification(at: newSession.plannedEndDate)
        liveActivity.start(session: newSession, hero: hero)
    }

    /// Called every second while the dungeon is on screen.
    func tick(at now: Date = .now) {
        guard var current = session else { return }
        current.update(at: now)
        session = current
        if current.state != .running {
            finish(at: now)
        } else {
            liveActivity.update(latest: run?.events(upToMinute: current.focusedMinutes(at: now)).last, session: current)
        }
    }

    func flee() {
        guard var current = session else { return }
        current.abandon()
        session = current
        finish(at: .now)
    }

    func dismissReport() {
        report = nil
        finale = nil
        save()
    }

    func endFinale() {
        finale = nil
    }

    private func finish(at now: Date) {
        guard let current = session else { return }
        // Rewards are settled right away; only the screen waits for the final scene.
        // The last room starts exactly at the end, so without this the boss fight would never be seen.
        if current.state == .completed, let run, let last = run.events.last(where: { $0.kind != .descend }),
           last.minute == current.plannedMinutes {
            let until = current.plannedEndDate.addingTimeInterval(DungeonScene.pause(for: last.kind) + 0.8)
            if until > now {
                finale = Finale(session: current, events: run.events, heroClass: hero.heroClass,
                                startHP: hero.maxHP, until: until)
            }
        }
        let report = Adventure.finish(current, hero: &hero, at: now)
        self.report = report
        history.append(SessionRecord(report: report, date: current.startDate))
        liveActivity.end(with: report)
        session = nil
        run = nil
        save()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.endNotificationID])
    }

    // MARK: Hero

    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hero.name = String(trimmed.prefix(20))
        save()
    }

    /// Runs a market action (buy, upgrade, sell) on the hero and saves the result.
    /// Like gear changes, trading is locked while a session runs.
    @discardableResult
    func trade<T>(_ action: (inout Hero) throws -> T) -> Result<T, MarketError> {
        guard session == nil else { return .failure(.itemNotFound) }
        do {
            let value = try action(&hero)
            save()
            return .success(value)
        } catch {
            // Market actions only throw MarketError; closures just can't spell out the type.
            return .failure(error as? MarketError ?? .itemNotFound)
        }
    }

    /// Gear is locked during a session, since the run was simulated with the old gear.
    func equip(_ item: Item) {
        guard session == nil else { return }
        hero.equip(item)
        save()
    }

    // MARK: Leaving the app

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background: appDidLeave()
        case .active: appDidReturn()
        // Inactive covers Control Center and incoming calls, which are fine.
        default: break
        }
    }

    private func appDidLeave() {
        guard session?.state == .running else { return }
        session?.appDidLeave()
        save()
        // Don't promise success while it's unclear whether the user is coming back.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.endNotificationID])
        // Stay awake briefly so the screen-lock notification can still reach us.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "lock-detection") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func appDidReturn() {
        endBackgroundTask()
        guard session != nil else { return }
        session?.appDidReturn()
        tick()
        save()
        if let session, session.state == .running {
            scheduleEndNotification(at: session.plannedEndDate)
        }
    }

    private func screenDidLock() {
        guard session != nil else { return }
        // On a real device the lock is reported about ten seconds late.
        session?.screenDidLock(detectionDelay: 10)
        tick()
        save()
        if let session, session.state == .running {
            scheduleEndNotification(at: session.plannedEndDate)
        }
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: Persistence & notifications

    /// Reads the save game. If it exists but can't be read, it is copied aside first,
    /// so starting over with a new hero never silently destroys the old one.
    private static func loadSaveGame() -> SaveGame? {
        guard let data = try? Data(contentsOf: saveURL) else { return nil }
        do {
            return try JSONDecoder().decode(SaveGame.self, from: data)
        } catch {
            let backup = URL.applicationSupportDirectory.appending(path: "savegame-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? data.write(to: backup)
            print("Spielstand nicht lesbar, Kopie unter \(backup.lastPathComponent): \(error)")
            return nil
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(SaveGame(hero: hero, session: session, report: report, history: history)).write(to: Self.saveURL, options: .atomic)
        } catch {
            print("Spielstand konnte nicht gespeichert werden: \(error)")
        }
    }

    private func scheduleEndNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Abenteuer bestanden! ⚔️"
            content.body = "Dein Held ist zurück. Der Abenteuerbericht wartet in der Taverne."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.endNotificationID, content: content, trigger: trigger))
        }
    }
}
