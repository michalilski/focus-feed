import Foundation

extension PlatformProfile {
    static let youtube = PlatformProfile(
        platform: .youtube,
        title: "YouTube",
        symbolName: "play.rectangle.fill",
        homeURL: URL(string: "https://m.youtube.com/feed/subscriptions")!,
        internalHosts: [
            "youtube.com", "youtu.be", "youtube-nocookie.com",
            "accounts.google.com", "accounts.google.pl", "accounts.youtube.com",
            "myaccount.google.com", "gds.google.com", "consent.google.com",
        ],
        rules: YouTubeRules.all,
        filterScriptName: "youtube",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0002")!,
        mediaRequiresUserAction: false
    )
}

enum YouTubeRules {
    static let shortsBlocked = BlockReason(
        title: "Shorts are off",
        message: "Shorts feeds are blocked. Pick a video from your subscriptions or search instead."
    )
    static let discoveryBlocked = BlockReason(
        title: "Recommendations are off",
        message: "Trending and Explore are blocked. Use search to find something specific."
    )

    static let all: [RouteRule] = [
        RewriteRule(rewrite: shortToWatch),
        BlockPathRule(prefixes: ["/shorts", "/feed/shorts"], reason: shortsBlocked),
        BlockPatternRule(pattern: "/(@[^/]+|(c|channel|user)/[^/]+)/shorts", reason: shortsBlocked),
        BlockPathRule(prefixes: ["/feed/trending", "/feed/explore"], reason: discoveryBlocked),
    ]

    private static func shortToWatch(_ url: URL) -> URL? {
        guard let match = url.normalizedPath.wholeMatch(of: /\/shorts\/([A-Za-z0-9_-]+)/) else { return nil }
        return url.replacingPath("/watch", queryItems: [URLQueryItem(name: "v", value: String(match.1))])
    }
}
