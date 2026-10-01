import Foundation

extension PlatformProfile {
    static let x = PlatformProfile(
        platform: .x,
        title: "X",
        symbolName: "bubble.left.fill",
        homeURL: URL(string: "https://x.com/home")!,
        internalHosts: ["x.com", "twitter.com"],
        rules: XRules.all,
        filterScriptName: "x",
        dataStoreID: UUID(uuidString: "7B6E0A51-0C7C-4B0E-9A53-6C1D5C0F0003")!,
        mediaRequiresUserAction: false
    )
}

enum XRules {
    static let discoveryBlocked = BlockReason(
        title: "Trends are off",
        message: "Trending and recommendations are blocked. Use search to find something specific."
    )
    static let extrasBlocked = BlockReason(
        title: "Not part of FocusFeed",
        message: "Grok, Communities discovery, Jobs and Premium upsells are blocked."
    )

    static let all: [RouteRule] = [
        BlockPathRule(prefixes: ["/i/trends", "/explore/tabs", "/i/connect_people", "/i/follow_people"], reason: discoveryBlocked),
        BlockPathRule(prefixes: ["/i/grok", "/jobs", "/i/premium_sign_up", "/i/communities/suggested", "/i/lists/suggested"], reason: extrasBlocked),
    ]
}
