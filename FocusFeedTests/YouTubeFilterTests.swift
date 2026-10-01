import XCTest
@testable import FocusFeed

final class YouTubeFilterTests: FilterFixtureTestCase {
    func testSearchResultsHideShorts() async throws {
        try await assertFixture("youtube-search", profile: .youtube, path: "/results?search_query=swift")
    }

    func testWatchPageHidesRecommendations() async throws {
        try await assertFixture("youtube-watch", profile: .youtube, path: "/watch?v=abc123")
    }
}
