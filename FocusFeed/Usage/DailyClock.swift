import Foundation

/// Time the app was on screen today, and when to suggest stopping.
struct DailyClock: Codable {
    static let nudgeAfter: TimeInterval = 15 * 60
    static let snoozeLength: TimeInterval = 5 * 60

    private(set) var day: Date
    private var accumulated: TimeInterval = 0
    private var activeSince: Date?
    private var nextNudge = Self.nudgeAfter

    private enum CodingKeys: String, CodingKey {
        case day, accumulated, nextNudge
    }

    init(day: Date) {
        self.day = day
    }

    mutating func resume(at now: Date, calendar: Calendar = .current) {
        rollOver(to: now, calendar: calendar)
        guard activeSince == nil else { return }
        activeSince = now
    }

    mutating func suspend(at now: Date, calendar: Calendar = .current) {
        rollOver(to: now, calendar: calendar)
        guard let activeSince else { return }
        accumulated += now.timeIntervalSince(activeSince)
        self.activeSince = nil
    }

    mutating func snooze(at now: Date, calendar: Calendar = .current) {
        rollOver(to: now, calendar: calendar)
        nextNudge = elapsed(at: now, calendar: calendar) + Self.snoozeLength
    }

    func elapsed(at now: Date, calendar: Calendar = .current) -> TimeInterval {
        let today = calendar.startOfDay(for: now)
        let running = activeSince.map { now.timeIntervalSince(max($0, today)) } ?? 0
        return today == day ? accumulated + running : running
    }

    func isNudgeDue(at now: Date, calendar: Calendar = .current) -> Bool {
        let threshold = calendar.startOfDay(for: now) == day ? nextNudge : Self.nudgeAfter
        return elapsed(at: now, calendar: calendar) >= threshold
    }

    private mutating func rollOver(to now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard today != day else { return }
        let carried = activeSince.map { max($0, today) }
        self = DailyClock(day: today)
        activeSince = carried
    }
}
