import Foundation

/// A focus session, computed purely from timestamps so it survives the app being
/// suspended in the background. The app reports leaving/returning; deciding whether
/// a screen lock counts as "leaving" is up to the app layer.
public struct FocusSession: Codable, Sendable {
    public enum State: String, Codable, Sendable {
        case running, completed, abandoned
    }

    /// How long the user may be away before the hero flees.
    public static let gracePeriod: TimeInterval = 10

    public let category: FocusCategory
    public let plannedMinutes: Int
    public let startDate: Date
    /// Seeds the dungeon, so the whole run is known from the start.
    public let seed: UInt64
    public private(set) var state: State = .running
    public private(set) var endDate: Date?
    public private(set) var leftAppAt: Date?

    public init(category: FocusCategory, plannedMinutes: Int, startDate: Date = .now, seed: UInt64 = .random(in: 0 ... .max)) {
        self.category = category
        self.plannedMinutes = plannedMinutes
        self.startDate = startDate
        self.seed = seed
    }

    public var plannedDuration: TimeInterval { TimeInterval(plannedMinutes * 60) }
    public var plannedEndDate: Date { startDate.addingTimeInterval(plannedDuration) }

    public func elapsed(at now: Date = .now) -> TimeInterval {
        let end = min(endDate ?? now, plannedEndDate)
        return max(0, end.timeIntervalSince(startDate))
    }

    public func remaining(at now: Date = .now) -> TimeInterval {
        plannedDuration - elapsed(at: now)
    }

    public func progress(at now: Date = .now) -> Double {
        plannedDuration > 0 ? elapsed(at: now) / plannedDuration : 1
    }

    /// Whole minutes actually focused; this is how deep the hero gets.
    public func focusedMinutes(at now: Date = .now) -> Int {
        Int(elapsed(at: now) / 60)
    }

    /// Call regularly (e.g. from a timer tick) to detect completion.
    public mutating func update(at now: Date = .now) {
        guard state == .running, now >= plannedEndDate else { return }
        state = .completed
        endDate = plannedEndDate
    }

    public mutating func appDidLeave(at now: Date = .now) {
        guard state == .running else { return }
        leftAppAt = now
    }

    public mutating func appDidReturn(at now: Date = .now) {
        guard state == .running, let left = leftAppAt else { return }
        leftAppAt = nil
        let deadline = left.addingTimeInterval(FocusSession.gracePeriod)
        // Finishing while still inside the grace period counts as success.
        if plannedEndDate <= deadline {
            update(at: now)
        } else if now > deadline {
            abandon(at: deadline)
        } else {
            update(at: now)
        }
    }

    /// The screen was locked rather than another app opened. That is allowed, unless the user
    /// was already away longer than the grace period before locking. `detectionDelay` is how late
    /// the system reports a lock, so that time doesn't count as being away.
    public mutating func screenDidLock(at now: Date = .now, detectionDelay: TimeInterval = 0) {
        guard state == .running, let left = leftAppAt else { return }
        leftAppAt = nil
        let awayBeforeLock = now.addingTimeInterval(-detectionDelay).timeIntervalSince(left)
        if awayBeforeLock > FocusSession.gracePeriod {
            abandon(at: left.addingTimeInterval(FocusSession.gracePeriod))
        }
    }

    public mutating func abandon(at now: Date = .now) {
        guard state == .running else { return }
        state = .abandoned
        endDate = min(now, plannedEndDate)
    }
}
