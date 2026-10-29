import Foundation
import Observation

@MainActor
@Observable
final class DailyTracker {
    private static let storageKey = "dailyClock"

    private(set) var minutes = 0
    private(set) var showsNudge = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var clock: DailyClock
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.clock = Self.load(from: defaults) ?? DailyClock(day: Calendar.current.startOfDay(for: .now))
    }

    func resume() {
        clock.resume(at: .now)
        save()
        refresh()
        startTicking()
    }

    func suspend() {
        clock.suspend(at: .now)
        save()
        ticker?.cancel()
        ticker = nil
    }

    func snooze() {
        clock.snooze(at: .now)
        save()
        refresh()
    }

    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let now = Date.now
        minutes = Int(clock.elapsed(at: now) / 60)
        showsNudge = clock.isNudgeDue(at: now)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(clock) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> DailyClock? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(DailyClock.self, from: data)
    }
}
