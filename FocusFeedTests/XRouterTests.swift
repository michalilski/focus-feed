import XCTest
@testable import FocusFeed

final class XRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .x }

    func testDiscoveryIsBlocked() {
        assertBlocked("https://x.com/i/trends")
        assertBlocked("https://x.com/explore/tabs/for-you")
        assertBlocked("https://x.com/i/connect_people")
    }

    func testExtrasAreBlocked() {
        assertBlocked("https://x.com/i/grok")
        assertBlocked("https://x.com/jobs")
        assertBlocked("https://x.com/i/premium_sign_up")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://x.com/home")
        assertAllowed("https://x.com/explore")
        assertAllowed("https://x.com/search?q=swift&src=typed_query")
        assertAllowed("https://x.com/someuser")
        assertAllowed("https://x.com/someuser/status/123456")
        assertAllowed("https://x.com/notifications")
        assertAllowed("https://x.com/messages")
        assertAllowed("https://x.com/i/chat")
        assertAllowed("https://x.com/i/lists/123")
        assertAllowed("https://x.com/i/bookmarks")
        assertAllowed("https://x.com/i/flow/login")
        assertAllowed("https://twitter.com/someuser")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://t.co/abc123")
        assertExternal("https://example.com/")
    }
}
