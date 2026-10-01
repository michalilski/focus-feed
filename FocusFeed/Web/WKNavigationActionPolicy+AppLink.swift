import WebKit

extension WKNavigationActionPolicy {
    /// WebKit's `_WKNavigationActionPolicyAllowWithoutTryingAppLink`: loads the page without handing universal links to other apps.
    static let allowWithoutTryingAppLink = WKNavigationActionPolicy(rawValue: WKNavigationActionPolicy.allow.rawValue + 2)!
}
