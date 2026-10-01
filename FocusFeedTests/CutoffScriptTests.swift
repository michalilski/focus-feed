import XCTest
@testable import FocusFeed

final class CutoffScriptTests: FilterFixtureTestCase {
    func testDepthCutoffAppliesOnSearchPage() async throws {
        let webView = try await loadFixture("cutoff-depth", profile: .youtube, path: "/results?search_query=swift")
        let cutoff = try await cutoffY(in: webView)
        XCTAssertEqual(cutoff, 6000)
    }

    func testDepthCutoffAppliesOnHomeFeed() async throws {
        let webView = try await loadFixture("cutoff-depth", profile: .youtube, path: "/")
        let cutoff = try await cutoffY(in: webView)
        XCTAssertEqual(cutoff, 6000)
    }

    func testNoCutoffOnWatchPage() async throws {
        let webView = try await loadFixture("cutoff-depth", profile: .youtube, path: "/watch?v=abc123")
        let cutoff = try await cutoffY(in: webView)
        XCTAssertNil(cutoff)
    }

    func testExtendingCutoffAddsOnePage() async throws {
        let webView = try await loadFixture("cutoff-depth", profile: .youtube, path: "/results?search_query=swift")
        _ = try await webView.evaluateJavaScript("FocusFeed.extendCutoff()", in: nil, contentWorld: .defaultClient)
        let cutoff = try await cutoffY(in: webView)
        XCTAssertEqual(cutoff, 12000)
    }
}
