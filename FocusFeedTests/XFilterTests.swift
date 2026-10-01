import XCTest
@testable import FocusFeed

final class XFilterTests: FilterFixtureTestCase {
    func testHomeHidesRecommendationsAndForYouTab() async throws {
        try await assertFixture("x-home", profile: .x, path: "/home")
    }

    func testStatusPageCutsDiscoverMore() async throws {
        try await assertFixture("x-status", profile: .x, path: "/friend/status/123")
    }

    func testExploreKeepsSearchBoxOnly() async throws {
        try await assertFixture("x-explore", profile: .x, path: "/explore")
    }
}
