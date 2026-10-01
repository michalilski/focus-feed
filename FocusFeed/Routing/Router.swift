import Foundation

struct Router {
    let profile: PlatformProfile

    func decide(_ url: URL) -> RouteDecision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }
        if scheme == "about" { return .allow }
        guard scheme == "https" else { return .cancel }
        guard profile.owns(url) else { return .external }
        for rule in profile.rules {
            if let decision = rule.decision(for: url) { return decision }
        }
        return .allow
    }
}
