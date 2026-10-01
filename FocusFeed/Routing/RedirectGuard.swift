import Foundation

struct RedirectGuard {
    private var lastSource: URL?
    private var lastTime: Date?
    let window: TimeInterval

    init(window: TimeInterval = 3) {
        self.window = window
    }

    mutating func shouldRedirect(from url: URL, now: Date = Date()) -> Bool {
        defer {
            lastSource = url
            lastTime = now
        }
        guard let lastSource, let lastTime, lastSource == url else { return true }
        return now.timeIntervalSince(lastTime) > window
    }
}
