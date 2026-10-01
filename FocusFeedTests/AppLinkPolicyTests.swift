import WebKit
import XCTest
@testable import FocusFeed

@MainActor
final class AppLinkPolicyTests: XCTestCase {
    func testAllowedNavigationNeverOpensAnotherApp() async {
        let session = BrowserSession(profile: .youtube, dataStore: .nonPersistent())
        let action = StubNavigationAction(url: URL(string: "https://m.youtube.com/feed/subscriptions")!)
        let policy = await session.webView(session.webView, decidePolicyFor: action)
        XCTAssertEqual(policy, .allowWithoutTryingAppLink)
    }

    func testBlockedNavigationIsCancelled() async {
        let session = BrowserSession(profile: .youtube, dataStore: .nonPersistent())
        let action = StubNavigationAction(url: URL(string: "https://m.youtube.com/feed/trending")!)
        let policy = await session.webView(session.webView, decidePolicyFor: action)
        XCTAssertEqual(policy, .cancel)
    }
}

final class StubNavigationAction: WKNavigationAction {
    private let stubRequest: URLRequest

    init(url: URL) {
        stubRequest = URLRequest(url: url)
        super.init()
    }

    override var request: URLRequest { stubRequest }
    override var targetFrame: WKFrameInfo? { nil }
}
