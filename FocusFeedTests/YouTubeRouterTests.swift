import XCTest
@testable import FocusFeed

final class YouTubeRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .youtube }

    func testHomeRedirectsToSubscriptions() {
        assertRedirect("https://m.youtube.com/", to: "https://m.youtube.com/feed/subscriptions")
        assertRedirect("https://www.youtube.com", to: "https://www.youtube.com/feed/subscriptions")
    }

    func testShortIsRewrittenToWatchPage() {
        assertRedirect("https://m.youtube.com/shorts/abc_DEF-123", to: "https://m.youtube.com/watch?v=abc_DEF-123")
        assertRedirect("https://m.youtube.com/shorts/abc123?feature=share", to: "https://m.youtube.com/watch?v=abc123")
    }

    func testShortsFeedsAreBlocked() {
        assertBlocked("https://m.youtube.com/shorts")
        assertBlocked("https://m.youtube.com/shorts/")
        assertBlocked("https://m.youtube.com/feed/shorts")
        assertBlocked("https://m.youtube.com/@somechannel/shorts")
        assertBlocked("https://m.youtube.com/channel/UC123/shorts")
    }

    func testDiscoveryIsBlocked() {
        assertBlocked("https://m.youtube.com/feed/trending")
        assertBlocked("https://m.youtube.com/feed/explore")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://m.youtube.com/feed/subscriptions")
        assertAllowed("https://m.youtube.com/watch?v=abc123")
        assertAllowed("https://m.youtube.com/results?search_query=swift")
        assertAllowed("https://m.youtube.com/@somechannel/videos")
        assertAllowed("https://m.youtube.com/playlist?list=PL123")
        assertAllowed("https://m.youtube.com/feed/library")
        assertAllowed("https://accounts.google.com/ServiceLogin")
        assertAllowed("about:blank")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://example.com/article")
        assertExternal("https://www.google.com/search?q=x")
        assertExternal("https://notyoutube.com/")
    }

    func testNonWebSchemesAreCancelled() {
        XCTAssertEqual(decide("youtube://watch?v=abc"), .cancel)
        XCTAssertEqual(decide("itms-apps://apps.apple.com/app/id544007664"), .cancel)
        XCTAssertEqual(decide("http://m.youtube.com/"), .cancel)
    }
}
