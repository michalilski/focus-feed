import Observation
import SwiftUI

struct ExternalPage: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor
@Observable
final class SessionStore {
    private static let selectionKey = "selectedPlatform"

    var selected: Platform {
        didSet { selectionDidChange(from: oldValue) }
    }
    var externalPage: ExternalPage?
    private(set) var sessions: [BrowserSession] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.selectionKey).flatMap(Platform.init(rawValue:))
        self.selected = stored ?? .youtube
    }

    func activateSelected() {
        session(for: selected).start()
    }

    func apply(_ options: LaunchOptions) {
        if let platform = options.platform {
            selected = platform
        }
        activateSelected()
        if let url = options.url {
            session(for: selected).load(url)
        }
        if let delay = options.snapshotDelay {
            scheduleSnapshot(after: delay)
        }
    }

    func pauseSelected() {
        session(for: selected).pause()
    }

    func saveSnapshot() async {
        guard let snapshot = try? await session(for: selected).snapshot() else { return }
        _ = try? PageSnapshotWriter().write(snapshot)
    }

    private func scheduleSnapshot(after delay: TimeInterval) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await saveSnapshot()
        }
    }

    func open(_ url: URL) {
        guard let owner = PlatformProfile.owner(of: url) else {
            externalPage = ExternalPage(url: url)
            return
        }
        selected = owner.platform
        let target = session(for: owner.platform)
        target.start()
        target.load(url)
    }

    func session(for platform: Platform) -> BrowserSession {
        if let existing = sessions.first(where: { $0.id == platform }) {
            return existing
        }
        let created = BrowserSession(profile: .profile(for: platform))
        created.onExternalLink = { [weak self] url in self?.open(url) }
        sessions.append(created)
        return created
    }

    private func selectionDidChange(from previous: Platform) {
        guard previous != selected else { return }
        defaults.set(selected.rawValue, forKey: Self.selectionKey)
        sessions.first { $0.id == previous }?.pause()
        activateSelected()
    }
}
