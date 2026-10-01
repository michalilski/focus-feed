import XCTest
@testable import FocusFeed

final class FilterMessageTests: XCTestCase {
    func testParsesStats() {
        let body: [String: Any] = ["type": "stats", "counts": ["shorts-shelf": 2], "leaks": ["shorts-link": 1]]
        let expected = FilterStats(hidden: ["shorts-shelf": 2], leaks: ["shorts-link": 1])
        XCTAssertEqual(FilterMessage(body: body), .stats(expected))
        XCTAssertEqual(expected.hiddenTotal, 2)
        XCTAssertEqual(expected.leakTotal, 1)
    }

    func testRejectsUnknownOrMalformedMessages() {
        XCTAssertNil(FilterMessage(body: "stats"))
        XCTAssertNil(FilterMessage(body: ["type": "unknown"]))
        XCTAssertNil(FilterMessage(body: ["type": "stats", "counts": "many"]))
    }

    func testParsesCutoff() {
        let body: [String: Any] = ["type": "cutoff", "y": 4200, "extendable": true]
        XCTAssertEqual(FilterMessage(body: body), .cutoff(Cutoff(y: 4200, extendable: true)))
    }

    func testParsesClearedCutoff() {
        let body: [String: Any] = ["type": "cutoff", "y": NSNull(), "extendable": false]
        XCTAssertEqual(FilterMessage(body: body), .cutoff(nil))
    }
}
