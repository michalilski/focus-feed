import WebKit
import XCTest
@testable import FocusFeed

@MainActor
final class ScrollLimitTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testScrollingStopsAtCutoffAndShowsPanel() async throws {
        let session = BrowserSession(profile: .youtube, dataStore: .nonPersistent())
        try show(session.webView)
        let html = """
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <body style="margin: 0"><div style="height: 20000px">Long list</div></body>
        """
        session.webView.loadHTMLString(html, baseURL: URL(string: "https://m.youtube.com/results?search_query=swift")!)
        try await waitUntil { session.cutoff != nil }

        let scrollView = session.webView.scrollView
        scrollView.contentOffset.y = 15000
        try await waitUntil { session.cutoffPanelTop != nil }

        let expected = 6000 - scrollView.bounds.height + CutoffGeometry.panelHeight
        XCTAssertEqual(scrollView.contentOffset.y, expected, accuracy: 1)
        XCTAssertEqual(session.cutoff, Cutoff(y: 6000, extendable: true))
    }

    private func show(_ webView: WKWebView) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        webView.frame = window.bounds
        window.addSubview(webView)
        window.isHidden = false
        self.window = window
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return XCTFail("Timed out waiting for condition") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
