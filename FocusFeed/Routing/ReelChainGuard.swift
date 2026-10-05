import Foundation

/// Stops swiping from one opened reel to the next.
struct ReelChainGuard {
    static let reason = BlockReason(
        title: "One reel at a time",
        message: "Swiping to the next reel is off. Go back to where you opened it."
    )

    private var currentReel: String?

    mutating func allows(_ url: URL, isClientSide: Bool) -> Bool {
        let reel = Self.reelID(in: url)
        if isClientSide, let currentReel, let reel, reel != currentReel {
            return false
        }
        currentReel = reel
        return true
    }

    static func reelID(in url: URL) -> String? {
        guard let match = url.normalizedPath.wholeMatch(of: /(?:\/[^\/]+)?\/reels?\/([A-Za-z0-9_-]+)/) else { return nil }
        return match.1 == "audio" ? nil : String(match.1)
    }
}
