import XCTest
@testable import FocusFeed

final class RedirectGuardTests: XCTestCase {
    private let url = URL(string: "https://www.instagram.com/")!
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFirstRedirectIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        XCTAssertTrue(redirectGuard.shouldRedirect(from: url, now: start))
    }

    func testRepeatedRedirectInsideWindowIsRefused() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        XCTAssertFalse(redirectGuard.shouldRedirect(from: url, now: start.addingTimeInterval(1)))
    }

    func testRepeatedRedirectAfterWindowIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        XCTAssertTrue(redirectGuard.shouldRedirect(from: url, now: start.addingTimeInterval(4)))
    }

    func testDifferentSourceIsPermitted() {
        var redirectGuard = RedirectGuard(window: 3)
        _ = redirectGuard.shouldRedirect(from: url, now: start)
        let other = URL(string: "https://www.instagram.com/reel/abc/")!
        XCTAssertTrue(redirectGuard.shouldRedirect(from: other, now: start.addingTimeInterval(1)))
    }
}
