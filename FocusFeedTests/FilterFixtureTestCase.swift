import WebKit
import XCTest
@testable import FocusFeed

struct FixtureElement: Decodable {
    let id: String
    let expect: String
    let hidden: Bool
}

@MainActor
class FilterFixtureTestCase: XCTestCase {
    func assertFixture(
        _ name: String,
        profile: PlatformProfile,
        path: String = "/",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let webView = try await loadFixture(name, profile: profile, path: path)
        let elements = try await readExpectations(in: webView)
        XCTAssertFalse(elements.isEmpty, "Fixture \(name) has no data-expect elements", file: file, line: line)
        for element in elements {
            let shouldBeHidden = element.expect == "hidden"
            XCTAssertEqual(element.hidden, shouldBeHidden, "#\(element.id) in \(name).html", file: file, line: line)
        }
        let leaks = try await leakCounts(in: webView)
        XCTAssertEqual(leaks.filter { $0.value != 0 }, [:], "Leaks in \(name).html", file: file, line: line)
    }

    func loadFixture(_ name: String, profile: PlatformProfile, path: String) async throws -> WKWebView {
        let bridge = FilterBridge()
        let webView = WebViewFactory().makeWebView(for: profile, bridge: bridge, dataStore: .nonPersistent())
        webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let html = try fixtureHTML(name)
        let baseURL = URL(string: path, relativeTo: profile.homeURL)!.absoluteURL
        let loaded = NavigationWaiter()
        webView.navigationDelegate = loaded
        webView.loadHTMLString(html, baseURL: baseURL)
        await loaded.wait()
        _ = try await webView.evaluateJavaScript("FocusFeed.tick()", in: nil, contentWorld: .defaultClient)
        return webView
    }

    func leakCounts(in webView: WKWebView) async throws -> [String: Int] {
        let result = try await webView.evaluateJavaScript("FocusFeed.leakCounts()", in: nil, contentWorld: .defaultClient)
        return result as? [String: Int] ?? [:]
    }

    func cutoffY(in webView: WKWebView) async throws -> Double? {
        let result = try await webView.evaluateJavaScript("FocusFeed.cutoffY", in: nil, contentWorld: .defaultClient)
        return result as? Double
    }

    private func fixtureHTML(_ name: String) throws -> String {
        let bundle = Bundle(for: FilterFixtureTestCase.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "html"), "Missing fixture \(name).html")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func readExpectations(in webView: WKWebView) async throws -> [FixtureElement] {
        let script = """
        JSON.stringify(Array.from(document.querySelectorAll("[data-expect]")).map((element) => ({
            id: element.id,
            expect: element.dataset.expect,
            hidden: element.getClientRects().length === 0 || element.getBoundingClientRect().height === 0
        })))
        """
        let result = try await webView.evaluateJavaScript(script)
        let json = try XCTUnwrap(result as? String)
        return try JSONDecoder().decode([FixtureElement].self, from: Data(json.utf8))
    }
}

final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var finished = false

    func wait() async {
        if finished { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished = true
        continuation?.resume()
        continuation = nil
    }
}
