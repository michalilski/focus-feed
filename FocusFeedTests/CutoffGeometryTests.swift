import XCTest
@testable import FocusFeed

final class CutoffGeometryTests: XCTestCase {
    private func geometry(cutoffY: CGFloat, zoom: CGFloat = 1) -> CutoffGeometry {
        CutoffGeometry(cutoffY: cutoffY, viewportHeight: 800, zoomScale: zoom, minimumOffset: 0)
    }

    func testMaximumOffsetLeavesRoomForPanel() {
        XCTAssertEqual(geometry(cutoffY: 5000).maximumOffset, 5000 - 800 + CutoffGeometry.panelHeight)
    }

    func testMaximumOffsetNeverGoesAboveTop() {
        XCTAssertEqual(geometry(cutoffY: 100).maximumOffset, 0)
    }

    func testMaximumOffsetRespectsZoom() {
        XCTAssertEqual(geometry(cutoffY: 5000, zoom: 2).maximumOffset, 10000 - 800 + CutoffGeometry.panelHeight)
    }

    func testPanelIsHiddenWhileCutoffIsBelowViewport() {
        XCTAssertNil(geometry(cutoffY: 5000).panelTop(at: 0))
    }

    func testPanelFollowsCutoffInsideViewport() {
        XCTAssertEqual(geometry(cutoffY: 5000).panelTop(at: 4400), 600)
    }

    func testPanelNeverStartsAboveViewport() {
        XCTAssertEqual(geometry(cutoffY: 100).panelTop(at: 300), 0)
    }
}
