import XCTest
@testable import FocusFeed

final class InstagramFilterTests: FilterFixtureTestCase {
    func testFeedHidesReelsAdsAndSuggestions() async throws {
        try await assertFixture("instagram-feed", profile: .instagram, path: "/?variant=following")
    }

    func testExploreLandingHidesGridButKeepsSearchBox() async throws {
        try await assertFixture("instagram-explore", profile: .instagram, path: "/explore/search/")
    }

    func testProfileContentIsUntouched() async throws {
        try await assertFixture("instagram-profile", profile: .instagram, path: "/friend/")
    }

    func testFeedCutoffStartsAtFirstRunOfOldPosts() async throws {
        let webView = try await loadFixture("cutoff-age", profile: .instagram, path: "/?variant=following")
        let cutoff = try await cutoffY(in: webView)
        XCTAssertEqual(cutoff, 1500)
    }
}
