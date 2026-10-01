import XCTest
@testable import FocusFeed

final class InstagramRouterTests: RouterTestCase {
    override var profile: PlatformProfile { .instagram }

    func testHomeIsForcedToFollowing() {
        assertRedirect("https://www.instagram.com/", to: "https://www.instagram.com/?variant=following")
        assertRedirect("https://www.instagram.com/?variant=home", to: "https://www.instagram.com/?variant=following")
        assertAllowed("https://www.instagram.com/?variant=following")
    }

    func testPostLoginLandingIsForcedToFollowing() {
        assertRedirect("https://www.instagram.com/?deoia=1", to: "https://www.instagram.com/?variant=following")
    }

    func testReelPagerIsRewrittenToSingleReel() {
        assertRedirect("https://www.instagram.com/reels/Cabc_123-x/", to: "https://www.instagram.com/reel/Cabc_123-x/")
        assertAllowed("https://www.instagram.com/reel/Cabc_123-x/")
        assertAllowed("https://www.instagram.com/someuser/reel/Cabc123/")
    }

    func testReelsFeedsAreBlocked() {
        assertBlocked("https://www.instagram.com/reels/")
        assertBlocked("https://www.instagram.com/reels")
        assertBlocked("https://www.instagram.com/reels/audio/12345/")
    }

    func testExploreGridRedirectsToSearch() {
        assertRedirect("https://www.instagram.com/explore/", to: "https://www.instagram.com/explore/search/")
        assertAllowed("https://www.instagram.com/explore/search/")
        assertAllowed("https://www.instagram.com/explore/search/keyword/?q=cats")
        assertAllowed("https://www.instagram.com/explore/tags/cats/")
        assertAllowed("https://www.instagram.com/explore/locations/123/warsaw/")
        assertBlocked("https://www.instagram.com/explore/people/")
    }

    func testKeptPagesAreAllowed() {
        assertAllowed("https://www.instagram.com/someuser/")
        assertAllowed("https://www.instagram.com/p/Cabc123/")
        assertAllowed("https://www.instagram.com/direct/inbox/")
        assertAllowed("https://www.instagram.com/direct/t/123456/")
        assertAllowed("https://www.instagram.com/stories/someuser/123/")
        assertAllowed("https://www.instagram.com/accounts/login/")
    }

    func testOtherSitesAreExternal() {
        assertExternal("https://example.com/")
    }
}
