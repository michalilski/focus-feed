import Foundation

extension PlatformProfile {
    static let instagram = PlatformProfile(
        platform: .instagram,
        title: "Instagram",
        symbolName: "camera.fill",
        homeURL: URL(string: "https://www.instagram.com/?variant=following")!,
        internalHosts: ["instagram.com", "facebook.com", "meta.com"],
        rules: InstagramRules.all,
        filterScriptName: "instagram",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0001")!,
        mediaRequiresUserAction: true
    )
}

enum InstagramRules {
    static let reelsBlocked = BlockReason(
        title: "Reels are off",
        message: "The Reels feed is blocked. Posts from people you follow are in your Following feed."
    )
    static let exploreBlocked = BlockReason(
        title: "Explore is off",
        message: "The Explore grid is blocked. Use search to find a specific account or tag."
    )

    static let all: [RouteRule] = [
        RewriteRule(rewrite: homeToFollowing),
        RewriteRule(rewrite: reelPagerToSingleReel),
        BlockPathRule(prefixes: ["/reels"], reason: reelsBlocked),
        RewriteRule(rewrite: exploreToSearch),
        BlockPathRule(prefixes: ["/explore/people"], reason: exploreBlocked),
    ]

    private static func homeToFollowing(_ url: URL) -> URL? {
        guard url.normalizedPath == "/", url.queryValue("variant") != "following" else { return nil }
        return url.replacingPath("/", queryItems: [URLQueryItem(name: "variant", value: "following")])
    }

    private static func reelPagerToSingleReel(_ url: URL) -> URL? {
        guard let match = url.normalizedPath.wholeMatch(of: /\/reels\/([A-Za-z0-9_-]+)/) else { return nil }
        guard match.1 != "audio" else { return nil }
        return url.replacingPath("/reel/\(match.1)/")
    }

    private static func exploreToSearch(_ url: URL) -> URL? {
        guard url.normalizedPath == "/explore" else { return nil }
        return url.replacingPath("/explore/search/")
    }
}
