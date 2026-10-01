import Foundation

struct PlatformProfile {
    let platform: Platform
    let title: String
    let symbolName: String
    let homeURL: URL
    let internalHosts: [String]
    let rules: [RouteRule]
    let filterScriptName: String
    let dataStoreID: UUID
    let mediaRequiresUserAction: Bool

    func owns(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return internalHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func profile(for platform: Platform) -> PlatformProfile {
        switch platform {
        case .instagram: return .instagram
        case .youtube: return .youtube
        case .x: return .x
        }
    }

    static func owner(of url: URL) -> PlatformProfile? {
        Platform.allCases.map(profile(for:)).first { $0.owns(url) }
    }
}
