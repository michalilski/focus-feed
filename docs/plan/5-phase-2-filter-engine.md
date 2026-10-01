# FocusFeed Implementation Plan — 5. Phase 2: filter engine

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** the JavaScript filter engine, the YouTube filter script, the Swift code that injects scripts into a web view and receives their messages, and the fixture test harness.

**Done when:** `make test` prints `** TEST SUCCEEDED **` with 31 tests and everything is committed.

---

### Task 1: The filter engine and platform scripts

**Files:**
- Create: `FocusFeed/Resources/Filters/common.js`, `youtube.js`, `instagram.js`, `x.js` (same folder)

- [ ] **Step 1: Create the engine**

How it works, so you can debug it:

- `install(config)` stores the rules, adds one `<style>` element to `<html>` (the page has no `<head>` yet at document start), starts a `MutationObserver` on the whole document and a scroll listener, and runs `tick()`.
- `tick()` is debounced to once per 150 ms. It re-adds the style if the site removed it, applies mark rules, runs actions, reports counters, and measures the cutoff.
- Each hide rule becomes its own CSS rule, so one invalid selector cannot disable the others.
- Every call into rule code goes through `safely()`, so one broken rule cannot stop the engine.
- `post()` only sends when something changed.

`FocusFeed/Resources/Filters/common.js`

```javascript
(function () {
  "use strict";
  if (window.FocusFeed) {
    return;
  }

  const HIDE_ATTRIBUTE = "data-focusfeed-hidden";
  const COLLAPSE_ATTRIBUTE = "data-focusfeed-collapsed";
  const STYLE_ID = "focusfeed-style";
  const TICK_DELAY_MS = 150;
  const OLD_RUN_LENGTH = 3;
  const COLLAPSE_STYLE =
    "height: 0 !important; min-height: 0 !important; margin: 0 !important; padding: 0 !important; " +
    "border: 0 !important; overflow: hidden !important; visibility: hidden !important;";

  class FilterEngine {
    constructor() {
      this.hideRules = [];
      this.markRules = [];
      this.actions = [];
      this.leakRules = [];
      this.cutoffPolicies = [];
      this.timer = null;
      this.lastStats = "";
      this.lastCutoff = "";
      this.cutoffKey = null;
      this.cutoffY = null;
      this.cutoffExtensions = 0;
    }

    install(config) {
      this.hideRules = config.hide || [];
      this.markRules = config.mark || [];
      this.actions = config.actions || [];
      this.leakRules = config.leaks || [];
      this.cutoffPolicies = config.cutoff || [];
      this.ensureStyle();
      const observer = new MutationObserver(() => this.schedule());
      observer.observe(document.documentElement, { childList: true, subtree: true });
      window.addEventListener("scroll", () => this.schedule(), { passive: true });
      this.tick();
    }

    styleText() {
      const rules = this.hideRules.map((rule) => `${rule.selector} { display: none !important; }`);
      rules.push(`[${HIDE_ATTRIBUTE}] { display: none !important; }`);
      rules.push(`[${COLLAPSE_ATTRIBUTE}] { ${COLLAPSE_STYLE} }`);
      return rules.join("\n");
    }

    ensureStyle() {
      if (document.getElementById(STYLE_ID)) {
        return;
      }
      const style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = this.styleText();
      document.documentElement.appendChild(style);
    }

    schedule() {
      if (this.timer !== null) {
        return;
      }
      this.timer = setTimeout(() => {
        this.timer = null;
        this.tick();
      }, TICK_DELAY_MS);
    }

    tick() {
      this.ensureStyle();
      this.applyMarks();
      this.runActions();
      this.reportStats();
      this.updateCutoff();
    }

    markAttribute(rule) {
      return rule.collapse ? COLLAPSE_ATTRIBUTE : HIDE_ATTRIBUTE;
    }

    applyMarks() {
      for (const rule of this.markRules) {
        const attribute = this.markAttribute(rule);
        const matches = new Set(this.safely(() => rule.find(), []));
        for (const stale of document.querySelectorAll(`[${attribute}="${rule.name}"]`)) {
          if (!matches.has(stale)) {
            stale.removeAttribute(attribute);
          }
        }
        for (const element of matches) {
          if (element && !element.hasAttribute(attribute)) {
            element.setAttribute(attribute, rule.name);
          }
        }
      }
    }

    runActions() {
      for (const action of this.actions) {
        this.safely(() => action.run(), null);
      }
    }

    reportStats() {
      const counts = {};
      for (const rule of this.hideRules) {
        counts[rule.name] = this.count(rule.selector);
      }
      for (const rule of this.markRules) {
        counts[rule.name] = this.count(`[${this.markAttribute(rule)}="${rule.name}"]`);
      }
      const message = { type: "stats", counts: counts, leaks: this.leakCounts() };
      const serialized = JSON.stringify(message);
      if (serialized === this.lastStats) {
        return;
      }
      this.lastStats = serialized;
      this.post(message);
    }

    leakCounts() {
      const leaks = {};
      for (const rule of this.leakRules) {
        leaks[rule.name] = this.safely(
          () => Array.from(document.querySelectorAll(rule.selector)).filter((element) => this.isRendered(element)).length,
          -1
        );
      }
      return leaks;
    }

    updateCutoff() {
      const policy = this.cutoffPolicies.find((candidate) => this.safely(() => candidate.applies(window.location), false));
      const key = policy ? `${policy.name}|${window.location.pathname}${window.location.search}` : null;
      if (key !== this.cutoffKey) {
        this.cutoffKey = key;
        this.cutoffY = null;
        this.cutoffExtensions = 0;
      }
      if (policy) {
        const measured = this.safely(() => this.measureCutoff(policy), null);
        if (measured !== null) {
          this.cutoffY = Math.round(measured);
        }
      }
      this.reportCutoff(policy);
    }

    measureCutoff(policy) {
      if (policy.maxDepth) {
        const depth = policy.maxDepth * (1 + this.cutoffExtensions);
        return document.documentElement.scrollHeight > depth ? depth : null;
      }
      const items = Array.from(document.querySelectorAll(policy.items)).filter((item) => this.isRendered(item));
      const limit = Date.now() - policy.maxAgeHours * 3600 * 1000;
      const old = items.map((item) => this.isOlderThan(item, limit));
      for (let index = 0; index < items.length; index += 1) {
        const run = old.slice(index, index + OLD_RUN_LENGTH);
        if (run.length === OLD_RUN_LENGTH && run.every(Boolean)) {
          return items[index].getBoundingClientRect().top + window.scrollY;
        }
      }
      return null;
    }

    isRendered(element) {
      const rects = element.getClientRects();
      return rects.length > 0 && rects[0].height > 0;
    }

    isOlderThan(item, limit) {
      const time = item.querySelector("time[datetime]");
      if (!time) {
        return false;
      }
      const stamp = Date.parse(time.getAttribute("datetime"));
      return !Number.isNaN(stamp) && stamp < limit;
    }

    reportCutoff(policy) {
      const message = { type: "cutoff", y: this.cutoffY, extendable: Boolean(policy && policy.maxDepth) };
      const serialized = JSON.stringify(message);
      if (serialized === this.lastCutoff) {
        return;
      }
      this.lastCutoff = serialized;
      this.post(message);
    }

    extendCutoff() {
      this.cutoffExtensions += 1;
      this.tick();
    }

    count(selector) {
      return this.safely(() => document.querySelectorAll(selector).length, -1);
    }

    safely(work, fallback) {
      try {
        return work();
      } catch (error) {
        return fallback;
      }
    }

    post(message) {
      const handlers = window.webkit && window.webkit.messageHandlers;
      if (handlers && handlers.focusFeed) {
        handlers.focusFeed.postMessage(message);
      }
    }

    containersOf(innerSelector, containerSelector) {
      const found = [];
      for (const inner of document.querySelectorAll(innerSelector)) {
        const container = inner.closest(containerSelector);
        if (container) {
          found.push(container);
        }
      }
      return found;
    }

    withText(selector, pattern) {
      return Array.from(document.querySelectorAll(selector)).filter((element) =>
        pattern.test((element.textContent || "").trim())
      );
    }
  }

  window.FocusFeed = new FilterEngine();
})();
```

- [ ] **Step 2: Create the YouTube script**

Selectors are from the open-source "Control Panel for YouTube" and a uBlock Shorts list, and were checked against the live site on 2026-10-01 (search and watch pages, logged out).

`FocusFeed/Resources/Filters/youtube.js`

```javascript
FocusFeed.install({
  hide: [
    { name: "shorts-nav-tab", selector: "ytm-pivot-bar-item-renderer:has(> div.pivot-shorts)" },
    { name: "home-nav-tab", selector: "ytm-pivot-bar-item-renderer:has(> div.pivot-w2w)" },
    { name: "shorts-shelf", selector: "ytm-reel-shelf-renderer" },
    { name: "shorts-section", selector: "ytm-rich-section-renderer:has(ytm-reel-shelf-renderer, ytm-shorts-lockup-view-model)" },
    { name: "shorts-grid-shelf", selector: "grid-shelf-view-model:has(ytm-shorts-lockup-view-model)" },
    { name: "shorts-list-item", selector: 'ytm-video-with-context-renderer:has(a[href^="/shorts"])' },
    { name: "shorts-grid-item", selector: 'ytm-rich-item-renderer:has(a[href^="/shorts"])' },
    { name: "channel-shorts-tab", selector: 'yt-tab-shape[tab-title="Shorts"]' },
    { name: "home-feed", selector: '.tab-content[tab-identifier="FEwhat_to_watch"]' },
    { name: "related-videos", selector: 'ytm-item-section-renderer[section-identifier="related-items"]' },
    { name: "endscreen-cards", selector: "#movie_player .ytp-ce-element" },
    { name: "endscreen-grid", selector: "#movie_player .ytp-endscreen-content" },
    { name: "endscreen-wall", selector: "#movie_player .ytp-videowall-still" },
    { name: "autoplay-countdown", selector: ".ytm-autonav-bar, .ytm-upnext-autoplay-container" },
  ],
  actions: [
    {
      name: "disable-autoplay",
      run: function () {
        const toggle = document.querySelector('button.ytm-autonav-toggle-button-container[aria-pressed="true"]');
        if (toggle) {
          toggle.click();
        }
      },
    },
  ],
  leaks: [
    { name: "shorts-link", selector: 'a[href^="/shorts"]' },
    { name: "related-video", selector: 'ytm-item-section-renderer[section-identifier="related-items"] a[href^="/watch"]' },
  ],
  cutoff: [
    {
      name: "search",
      applies: function (location) {
        return location.pathname === "/results";
      },
      maxDepth: 6000,
    },
    {
      name: "subscriptions",
      applies: function (location) {
        return location.pathname === "/feed/subscriptions";
      },
      maxDepth: 9000,
    },
  ],
});
```

- [ ] **Step 3: Create placeholder scripts for Instagram and X**

Both files have the same single line for now. Phases 5 and 6 replace them.

`FocusFeed/Resources/Filters/instagram.js`

```javascript
FocusFeed.install({});
```

`FocusFeed/Resources/Filters/x.js`

```javascript
FocusFeed.install({});
```

---

### Task 2: Messages from the page

**Files:**
- Create: `FocusFeedTests/FilterMessageTests.swift`
- Create: `FocusFeed/Web/FilterMessage.swift`

- [ ] **Step 1: Write the failing tests**

`FocusFeedTests/FilterMessageTests.swift`

```swift
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
```

- [ ] **Step 2: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`, `error: cannot find 'FilterMessage' in scope`.

- [ ] **Step 3: Implement**

Numbers coming from JavaScript arrive as `NSNumber`, which is why `y` is read through `NSNumber`. A `null` cutoff arrives as `NSNull` and becomes `nil`.

`FocusFeed/Web/FilterMessage.swift`

```swift
import Foundation

struct FilterStats: Equatable {
    var hidden: [String: Int] = [:]
    var leaks: [String: Int] = [:]

    var hiddenTotal: Int { hidden.values.filter { $0 > 0 }.reduce(0, +) }
    var leakTotal: Int { leaks.values.filter { $0 > 0 }.reduce(0, +) }
}

struct Cutoff: Equatable {
    let y: Double
    let extendable: Bool
}

enum FilterMessage: Equatable {
    case stats(FilterStats)
    case cutoff(Cutoff?)

    init?(body: Any) {
        guard let payload = body as? [String: Any], let type = payload["type"] as? String else { return nil }
        switch type {
        case "stats":
            guard let counts = payload["counts"] as? [String: Int] else { return nil }
            self = .stats(FilterStats(hidden: counts, leaks: payload["leaks"] as? [String: Int] ?? [:]))
        case "cutoff":
            self = .cutoff(Self.cutoff(from: payload))
        default:
            return nil
        }
    }

    private static func cutoff(from payload: [String: Any]) -> Cutoff? {
        guard let y = (payload["y"] as? NSNumber)?.doubleValue, y >= 0 else { return nil }
        return Cutoff(y: y, extendable: payload["extendable"] as? Bool ?? false)
    }
}
```

- [ ] **Step 4: Run and confirm success**

```bash
make test
```

Expected: `Executed 26 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add FocusFeed/Resources/Filters FocusFeed/Web/FilterMessage.swift FocusFeedTests/FilterMessageTests.swift
git commit -m "feat: filter engine script and message parsing"
```

---

### Task 3: Injecting scripts into a web view

**Files:**
- Create: `FocusFeed/Web/FilterBridge.swift`, `FocusFeed/Web/FilterScriptLibrary.swift`, `FocusFeed/Web/WebViewFactory.swift`

- [ ] **Step 1: Create the message handler**

It ignores messages from sub-frames and anything `FilterMessage` cannot parse.

`FocusFeed/Web/FilterBridge.swift`

```swift
import WebKit

final class FilterBridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "focusFeed"

    var onMessage: ((FilterMessage) -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let parsed = FilterMessage(body: message.body) else { return }
        onMessage?(parsed)
    }
}
```

- [ ] **Step 2: Create the script library**

It joins `common.js` and the platform script into one user script, injected at document start, main frame only, in the isolated world. XcodeGen copies `.js` files flat into the app bundle, so they are looked up by name without a folder.

`FocusFeed/Web/FilterScriptLibrary.swift`

```swift
import WebKit

struct FilterScriptLibrary {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func source(for profile: PlatformProfile) -> String {
        [load("common"), load(profile.filterScriptName)].joined(separator: "\n")
    }

    func userScript(for profile: PlatformProfile) -> WKUserScript {
        WKUserScript(
            source: source(for: profile),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .defaultClient
        )
    }

    private func load(_ name: String) -> String {
        guard let url = bundle.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing filter script \(name).js")
        }
        return text
    }
}
```

- [ ] **Step 3: Create the web view factory**

`applicationNameForUserAgent` replaces the default suffix `Mobile/15E148`, which makes the user agent identical in shape to Safari's. Sites treat a bare web view user agent as an in-app browser and may block login. The `dataStore` parameter exists so tests can pass a non-persistent store.

`FocusFeed/Web/WebViewFactory.swift`

```swift
import WebKit

@MainActor
struct WebViewFactory {
    static let safariUserAgentSuffix = "Version/26.0 Mobile/15E148 Safari/604.1"

    let scripts: FilterScriptLibrary

    init(scripts: FilterScriptLibrary = FilterScriptLibrary()) {
        self.scripts = scripts
    }

    func makeWebView(
        for profile: PlatformProfile,
        bridge: FilterBridge,
        dataStore: WKWebsiteDataStore? = nil
    ) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration(for: profile, bridge: bridge, dataStore: dataStore))
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    private func configuration(
        for profile: PlatformProfile,
        bridge: FilterBridge,
        dataStore: WKWebsiteDataStore?
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore ?? WKWebsiteDataStore(forIdentifier: profile.dataStoreID)
        configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = profile.mediaRequiresUserAction ? .all : []
        configuration.userContentController.addUserScript(scripts.userScript(for: profile))
        configuration.userContentController.add(bridge, contentWorld: .defaultClient, name: FilterBridge.handlerName)
        return configuration
    }
}
```

- [ ] **Step 4: Build**

```bash
make build
```

Expected: no output and exit code 0.

---

### Task 4: Fixture harness and YouTube filter tests

**Files:**
- Create: `FocusFeedTests/FilterFixtureTestCase.swift`, `FocusFeedTests/YouTubeFilterTests.swift`
- Create: `FocusFeedTests/Fixtures/youtube-search.html`, `FocusFeedTests/Fixtures/youtube-watch.html`

- [ ] **Step 1: Create the harness**

`loadFixture` builds a web view with the real factory, loads the fixture HTML with the platform's host as base URL, waits for the load, and forces one engine tick in the isolated world. `assertFixture` then compares every `data-expect` element with what is rendered and checks the leak counters.

`FocusFeedTests/FilterFixtureTestCase.swift`

```swift
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
```

- [ ] **Step 2: Create the search fixture**

`FocusFeedTests/Fixtures/youtube-search.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<ytm-search>
  <lazy-list>
    <ytm-video-with-context-renderer id="normal-result" data-expect="visible">
      <a href="/watch?v=abc123">A normal video</a>
    </ytm-video-with-context-renderer>
    <ytm-video-with-context-renderer id="short-result" data-expect="hidden">
      <a href="/shorts/xyz789">A short in results</a>
    </ytm-video-with-context-renderer>
    <ytm-reel-shelf-renderer id="shorts-shelf" data-expect="hidden">
      <a href="/shorts/s1">Short 1</a>
    </ytm-reel-shelf-renderer>
    <grid-shelf-view-model id="shorts-grid-shelf" data-expect="hidden">
      <ytm-shorts-lockup-view-model><a href="/shorts/s2">Short 2</a></ytm-shorts-lockup-view-model>
    </grid-shelf-view-model>
    <grid-shelf-view-model id="plain-grid-shelf" data-expect="visible">
      <a href="/watch?v=def456">A shelf without shorts</a>
    </grid-shelf-view-model>
  </lazy-list>
</ytm-search>
<ytm-pivot-bar-renderer>
  <ytm-pivot-bar-item-renderer id="nav-home" data-expect="hidden"><div class="pivot-bar-item-tab pivot-w2w">Home</div></ytm-pivot-bar-item-renderer>
  <ytm-pivot-bar-item-renderer id="nav-shorts" data-expect="hidden"><div class="pivot-bar-item-tab pivot-shorts">Shorts</div></ytm-pivot-bar-item-renderer>
  <ytm-pivot-bar-item-renderer id="nav-subs" data-expect="visible"><div class="pivot-bar-item-tab pivot-subs">Subscriptions</div></ytm-pivot-bar-item-renderer>
</ytm-pivot-bar-renderer>
</body>
</html>
```

- [ ] **Step 3: Create the watch page fixture**

`FocusFeedTests/Fixtures/youtube-watch.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body>
<div id="movie_player" class="html5-video-player">
  <div id="player-surface" data-expect="visible">video</div>
  <div id="endscreen-card" class="ytp-ce-element" data-expect="hidden">card</div>
  <div id="endscreen-grid" class="ytp-endscreen-content" data-expect="hidden">grid</div>
</div>
<ytm-slim-video-metadata-section-renderer id="video-title" data-expect="visible">Title</ytm-slim-video-metadata-section-renderer>
<ytm-item-section-renderer id="comments" section-identifier="comments-entry-point" data-expect="visible">Comments</ytm-item-section-renderer>
<ytm-item-section-renderer id="related" section-identifier="related-items" data-expect="hidden">
  <lazy-list>
    <ytm-video-with-context-renderer><a href="/watch?v=next1">Up next</a></ytm-video-with-context-renderer>
  </lazy-list>
</ytm-item-section-renderer>
</body>
</html>
```

- [ ] **Step 4: Create the tests**

`FocusFeedTests/YouTubeFilterTests.swift`

```swift
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
```

- [ ] **Step 5: Run**

```bash
make test
```

Expected: `Executed 28 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Prove the tests can fail**

Temporarily delete the line containing `related-videos` from `FocusFeed/Resources/Filters/youtube.js`, then:

```bash
./scripts/test.sh -only-testing:FocusFeedTests/YouTubeFilterTests
```

Expected: `** TEST FAILED **` with an error mentioning `#related in youtube-watch.html`. Restore the file with `git checkout FocusFeed/Resources/Filters/youtube.js`, run the command again and confirm `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add FocusFeed/Web FocusFeedTests
git commit -m "feat: script injection and YouTube filter fixture tests"
```

---

### Task 5: Cutoff script tests

**Files:**
- Create: `FocusFeedTests/Fixtures/cutoff-depth.html`, `FocusFeedTests/CutoffScriptTests.swift`

The YouTube script declares depth cutoffs: 6000 px on search results, 9000 px on the subscriptions feed. A depth cutoff only applies when the page is taller than the depth.

- [ ] **Step 1: Create the fixture**

`FocusFeedTests/Fixtures/cutoff-depth.html`

```html
<!doctype html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin: 0">
<ytm-search><div style="height: 20000px">Long result list</div></ytm-search>
</body>
</html>
```

- [ ] **Step 2: Create the tests**

`FocusFeedTests/CutoffScriptTests.swift`

```swift
import XCTest
@testable import FocusFeed

final class CutoffScriptTests: FilterFixtureTestCase {
    func testDepthCutoffAppliesOnSearchPage() async throws {
        let webView = try await loadFixture("cutoff-depth", profile: .youtube, path: "/results?search_query=swift")
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
```

- [ ] **Step 3: Run**

```bash
make test
```

Expected: `Executed 31 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit and update the changelog**

Set phase 2 to "done" in `docs/plan/changelog.md` and add a log line.

```bash
make audit
git add FocusFeedTests docs/plan/changelog.md
git commit -m "test: cutoff script tests; phase 2 complete"
```
