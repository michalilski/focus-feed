# FocusFeed Implementation Plan — 6. Phase 3: browser shell

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans. Read files 1–3 of this plan first.

**Goal of this phase:** the real app. Three filtered web views behind a top bar, the blocked screen, the caught-up stop, the Filters sheet with DOM snapshots, the live probe, and the first install on the iPhone.

**Done when:** `make test` passes with 38 tests, `make uitest` passes with 2 tests, the live probes in task 7 give the expected reports, and the app runs on the phone.

---

### Task 1: Cutoff geometry

**Files:**
- Create: `FocusFeedTests/CutoffGeometryTests.swift`
- Create: `FocusFeed/Web/CutoffGeometry.swift`

The page reports a cutoff as a Y position in page coordinates. `CutoffGeometry` turns it into two numbers: the largest scroll offset allowed, and where the caught-up panel's top edge sits in the web view. The panel always gets at least `panelHeight` points of room, and the page zoom is taken into account.

- [ ] **Step 1: Write the failing tests**

`FocusFeedTests/CutoffGeometryTests.swift`

```swift
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
```

- [ ] **Step 2: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`, `error: cannot find 'CutoffGeometry' in scope`.

- [ ] **Step 3: Implement**

`FocusFeed/Web/CutoffGeometry.swift`

```swift
import CoreGraphics

struct CutoffGeometry {
    static let panelHeight: CGFloat = 200

    let cutoffY: CGFloat
    let viewportHeight: CGFloat
    let zoomScale: CGFloat
    let minimumOffset: CGFloat

    private var scaledCutoff: CGFloat { cutoffY * zoomScale }

    var maximumOffset: CGFloat {
        max(minimumOffset, scaledCutoff - viewportHeight + Self.panelHeight)
    }

    func panelTop(at offset: CGFloat) -> CGFloat? {
        let top = scaledCutoff - offset
        return top < viewportHeight ? max(0, top) : nil
    }
}
```

- [ ] **Step 4: Run and confirm success**

```bash
make test
```

Expected: `Executed 37 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add FocusFeed/Web/CutoffGeometry.swift FocusFeedTests/CutoffGeometryTests.swift
git commit -m "feat: cutoff geometry"
```

---

### Task 2: Session helpers

**Files:**
- Create: `FocusFeed/Web/ScrollLimiter.swift`, `FocusFeed/Web/DialogPresenter.swift`, `FocusFeed/Web/PageSnapshot.swift`

- [ ] **Step 1: Create the scroll limiter**

It is the web view's scroll view delegate. On every scroll and every cutoff change it clamps the offset and reports where the panel should be.

`FocusFeed/Web/ScrollLimiter.swift`

```swift
import UIKit

@MainActor
final class ScrollLimiter: NSObject, UIScrollViewDelegate {
    var cutoffY: CGFloat? {
        didSet { refresh() }
    }
    var onPanelTopChange: ((CGFloat?) -> Void)?

    private weak var scrollView: UIScrollView?

    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        scrollView.delegate = self
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refresh()
    }

    private func refresh() {
        guard let scrollView, let geometry = geometry(for: scrollView) else {
            onPanelTopChange?(nil)
            return
        }
        if scrollView.contentOffset.y > geometry.maximumOffset {
            scrollView.contentOffset.y = geometry.maximumOffset
        }
        onPanelTopChange?(geometry.panelTop(at: scrollView.contentOffset.y))
    }

    private func geometry(for scrollView: UIScrollView) -> CutoffGeometry? {
        guard let cutoffY else { return nil }
        return CutoffGeometry(
            cutoffY: cutoffY,
            viewportHeight: scrollView.bounds.height,
            zoomScale: scrollView.zoomScale,
            minimumOffset: -scrollView.adjustedContentInset.top
        )
    }
}
```

- [ ] **Step 2: Create the dialog presenter**

Without a `WKUIDelegate`, JavaScript `alert`, `confirm` and `prompt` are silently dropped and things like "Discard post?" stop working. Every path must call the completion handler exactly once, or WebKit crashes the app; that is what `fallback` is for. `createWebViewWith` handles links that want a new window: there are no windows, so the URL is passed back to the session.

`FocusFeed/Web/DialogPresenter.swift`

```swift
import WebKit

@MainActor
final class DialogPresenter: NSObject, WKUIDelegate {
    var onNewWindow: ((URL) -> Void)?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            onNewWindow?(url)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, from: webView, fallback: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, from: webView) { completionHandler(false) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        present(alert, from: webView) { completionHandler(nil) }
    }

    private func present(_ alert: UIAlertController, from webView: WKWebView, fallback: @escaping () -> Void) {
        guard let presenter = webView.window?.rootViewController, presenter.presentedViewController == nil else {
            fallback()
            return
        }
        presenter.present(alert, animated: true)
    }
}
```

- [ ] **Step 3: Create the snapshot types**

`FocusFeed/Web/PageSnapshot.swift`

```swift
import Foundation

struct PageSnapshot {
    let platform: Platform
    let url: URL?
    let html: String
    let userAgent: String
    let stats: FilterStats
}

struct PageSnapshotWriter {
    let directory: URL

    init(directory: URL = URL.documentsDirectory.appending(path: "snapshots")) {
        self.directory = directory
    }

    @discardableResult
    func write(_ snapshot: PageSnapshot) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = directory.appending(path: snapshot.platform.rawValue)
        let htmlFile = base.appendingPathExtension("html")
        try snapshot.html.write(to: htmlFile, atomically: true, encoding: .utf8)
        try JSONSerialization.data(withJSONObject: report(for: snapshot), options: [.prettyPrinted, .sortedKeys])
            .write(to: base.appendingPathExtension("json"))
        return htmlFile
    }

    private func report(for snapshot: PageSnapshot) -> [String: Any] {
        [
            "url": snapshot.url?.absoluteString ?? "",
            "userAgent": snapshot.userAgent,
            "hidden": snapshot.stats.hidden,
            "leaks": snapshot.stats.leaks,
        ]
    }
}
```

---

### Task 3: BrowserSession

**Files:**
- Create: `FocusFeed/Web/BrowserSession.swift`, `FocusFeed/Web/BrowserSession+Navigation.swift`
- Create: `FocusFeedTests/ScrollLimitTests.swift`

`BrowserSession` owns one web view and is the only place where routing decisions are turned into actions. Read `handle(_:isClientSide:)` carefully:

- It is called from `decidePolicyFor` with `isClientSide: false` (a real navigation that can still be cancelled) and from the `url` observer with `isClientSide: true` (the page already changed its URL with `pushState`).
- On a block from the client side the page is already showing the blocked content, so the session goes back (or home if there is no history).
- Redirects go through `RedirectGuard`; a refused redirect becomes `.allow`.
- The return value tells `decidePolicyFor` whether to let the navigation continue.

- [ ] **Step 1: Write the integration test**

It loads a 20000 px tall page under a YouTube search URL, tries to scroll to 15000, and expects the scroll view to be held at the cutoff.

`FocusFeedTests/ScrollLimitTests.swift`

```swift
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
```

- [ ] **Step 2: Run and confirm failure**

```bash
make test
```

Expected: `** TEST FAILED **`, `error: cannot find 'BrowserSession' in scope`.

- [ ] **Step 3: Create the session**

`FocusFeed/Web/BrowserSession.swift`

```swift
import Observation
import WebKit

@MainActor
@Observable
final class BrowserSession: NSObject, Identifiable {
    let id: Platform
    let profile: PlatformProfile
    let webView: WKWebView

    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0
    private(set) var currentURL: URL?
    private(set) var stats = FilterStats()
    private(set) var cutoff: Cutoff?
    private(set) var cutoffPanelTop: CGFloat?
    var blockReason: BlockReason?
    var loadError: String?
    var onExternalLink: ((URL) -> Void)?

    @ObservationIgnored private let router: Router
    @ObservationIgnored private let bridge: FilterBridge
    @ObservationIgnored private let dialogs = DialogPresenter()
    @ObservationIgnored private let scrollLimiter = ScrollLimiter()
    @ObservationIgnored private var redirectGuard = RedirectGuard()
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var hasStarted = false

    init(profile: PlatformProfile, factory: WebViewFactory? = nil, dataStore: WKWebsiteDataStore? = nil) {
        let bridge = FilterBridge()
        self.id = profile.platform
        self.profile = profile
        self.router = Router(profile: profile)
        self.bridge = bridge
        self.webView = (factory ?? WebViewFactory()).makeWebView(for: profile, bridge: bridge, dataStore: dataStore)
        super.init()
        connect()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        goHome()
    }

    func goHome() {
        load(profile.homeURL)
    }

    func load(_ url: URL) {
        loadError = nil
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        loadError = nil
        if webView.url == nil {
            goHome()
        } else {
            webView.reload()
        }
    }

    func pause() {
        webView.pauseAllMediaPlayback()
    }

    func extendCutoff() {
        webView.evaluateJavaScript("FocusFeed.extendCutoff()", in: nil, in: .defaultClient, completionHandler: nil)
    }

    func snapshot() async throws -> PageSnapshot {
        let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        let userAgent = try await webView.evaluateJavaScript("navigator.userAgent") as? String
        return PageSnapshot(
            platform: id,
            url: webView.url,
            html: html ?? "",
            userAgent: userAgent ?? "",
            stats: stats
        )
    }

    func dismissBlock() {
        blockReason = nil
        if webView.url == nil {
            goHome()
        }
    }

    func handle(_ url: URL, isClientSide: Bool) -> Bool {
        switch guardedDecision(for: url) {
        case .allow:
            return true
        case .redirect(let target):
            load(target)
            return false
        case .block(let reason):
            blockReason = reason
            if isClientSide { retreat() }
            return false
        case .external:
            onExternalLink?(url)
            return false
        case .cancel:
            return false
        }
    }

    private func guardedDecision(for url: URL) -> RouteDecision {
        let decision = router.decide(url)
        if case .redirect = decision, !redirectGuard.shouldRedirect(from: url) {
            return .allow
        }
        return decision
    }

    private func retreat() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            goHome()
        }
    }

    private func connect() {
        webView.navigationDelegate = self
        webView.uiDelegate = dialogs
        dialogs.onNewWindow = { [weak self] url in
            guard let self, self.handle(url, isClientSide: false) else { return }
            self.load(url)
        }
        bridge.onMessage = { [weak self] message in
            self?.receive(message)
        }
        installRefreshControl()
        scrollLimiter.attach(to: webView.scrollView)
        scrollLimiter.onPanelTopChange = { [weak self] top in
            guard let self, self.cutoffPanelTop != top else { return }
            self.cutoffPanelTop = top
        }
        observeWebView()
    }

    private func receive(_ message: FilterMessage) {
        switch message {
        case .stats(let stats):
            self.stats = stats
        case .cutoff(let cutoff):
            self.cutoff = cutoff
            scrollLimiter.cutoffY = cutoff.map { CGFloat($0.y) }
        }
    }

    private func installRefreshControl() {
        let control = UIRefreshControl()
        control.addAction(UIAction { [weak self, weak control] _ in
            self?.reload()
            control?.endRefreshing()
        }, for: .valueChanged)
        webView.scrollView.refreshControl = control
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.canGoBack) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.isLoading) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.estimatedProgress) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
            webView.observe(\.url) { [weak self] view, _ in
                Task { @MainActor in self?.urlDidChange(view.url) }
            },
        ]
    }

    private func urlDidChange(_ url: URL?) {
        currentURL = url
        guard let url else { return }
        _ = handle(url, isClientSide: true)
    }
}
```

- [ ] **Step 4: Create the navigation delegate extension**

Sub-frame navigations are always allowed (captchas and login widgets live in iframes). Error code 102 is WebKit's "frame load interrupted", which is what our own cancellations produce; it and `NSURLErrorCancelled` are not real errors.

`FocusFeed/Web/BrowserSession+Navigation.swift`

```swift
import WebKit

extension BrowserSession: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if let frame = navigationAction.targetFrame, !frame.isMainFrame {
            return .allow
        }
        return handle(url, isClientSide: false) ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    private func report(_ error: Error) {
        let code = (error as NSError).code
        let ignored = [NSURLErrorCancelled, 102]
        guard !ignored.contains(code) else { return }
        loadError = error.localizedDescription
    }
}
```

- [ ] **Step 5: Run and confirm success**

```bash
make test
```

Expected: `Executed 38 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add FocusFeed/Web FocusFeedTests/ScrollLimitTests.swift
git commit -m "feat: browser session with routing, cutoff and snapshots"
```

---

### Task 4: App state

**Files:**
- Create: `FocusFeed/App/LaunchOptions.swift`, `FocusFeed/App/SessionStore.swift`

- [ ] **Step 1: Create the launch options**

`UserDefaults` reads launch arguments automatically: launching with `-FFURL https://…` makes `string(forKey: "FFURL")` return that value. The live probe uses this.

`FocusFeed/App/LaunchOptions.swift`

```swift
import Foundation

struct LaunchOptions {
    let platform: Platform?
    let url: URL?
    let snapshotDelay: TimeInterval?

    init(defaults: UserDefaults = .standard) {
        platform = defaults.string(forKey: "FFPlatform").flatMap(Platform.init(rawValue:))
        url = defaults.string(forKey: "FFURL").flatMap(URL.init(string:))
        let delay = defaults.double(forKey: "FFSnapshotAfter")
        snapshotDelay = delay > 0 ? delay : nil
    }
}
```

- [ ] **Step 2: Create the session store**

Sessions are created the first time a platform is selected. `open(_:)` is where external links end up: a URL owned by one of the platforms switches to that tab, anything else goes to the Safari sheet.

`FocusFeed/App/SessionStore.swift`

```swift
import Observation
import SwiftUI

struct ExternalPage: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor
@Observable
final class SessionStore {
    private static let selectionKey = "selectedPlatform"

    var selected: Platform {
        didSet { selectionDidChange(from: oldValue) }
    }
    var externalPage: ExternalPage?
    private(set) var sessions: [BrowserSession] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.selectionKey).flatMap(Platform.init(rawValue:))
        self.selected = stored ?? .youtube
    }

    func activateSelected() {
        session(for: selected).start()
    }

    func apply(_ options: LaunchOptions) {
        if let platform = options.platform {
            selected = platform
        }
        activateSelected()
        if let url = options.url {
            session(for: selected).load(url)
        }
        if let delay = options.snapshotDelay {
            scheduleSnapshot(after: delay)
        }
    }

    func saveSnapshot() async {
        guard let snapshot = try? await session(for: selected).snapshot() else { return }
        _ = try? PageSnapshotWriter().write(snapshot)
    }

    private func scheduleSnapshot(after delay: TimeInterval) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await saveSnapshot()
        }
    }

    func open(_ url: URL) {
        guard let owner = PlatformProfile.owner(of: url) else {
            externalPage = ExternalPage(url: url)
            return
        }
        selected = owner.platform
        let target = session(for: owner.platform)
        target.start()
        target.load(url)
    }

    func session(for platform: Platform) -> BrowserSession {
        if let existing = sessions.first(where: { $0.id == platform }) {
            return existing
        }
        let created = BrowserSession(profile: .profile(for: platform))
        created.onExternalLink = { [weak self] url in self?.open(url) }
        sessions.append(created)
        return created
    }

    private func selectionDidChange(from previous: Platform) {
        guard previous != selected else { return }
        defaults.set(selected.rawValue, forKey: Self.selectionKey)
        sessions.first { $0.id == previous }?.pause()
        activateSelected()
    }
}
```

---

### Task 5: User interface

**Files:**
- Create: `FocusFeed/UI/WebViewContainer.swift`, `FocusFeed/UI/SafariView.swift`, `FocusFeed/UI/BlockedView.swift`, `FocusFeed/UI/CaughtUpPanel.swift`, `FocusFeed/UI/FilterStatsView.swift`, `FocusFeed/UI/TopBar.swift`, `FocusFeed/UI/BrowserScreen.swift`
- Replace: `FocusFeed/App/RootView.swift`

- [ ] **Step 1: Create the web view wrapper**

`FocusFeed/UI/WebViewContainer.swift`

```swift
import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
```

- [ ] **Step 2: Create the Safari sheet**

`FocusFeed/UI/SafariView.swift`

```swift
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
```

- [ ] **Step 3: Create the blocked and error views**

`FocusFeed/UI/BlockedView.swift`

```swift
import SwiftUI

struct BlockedView: View {
    let reason: BlockReason
    let onDismiss: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(reason.title, systemImage: "leaf.fill")
        } description: {
            Text(reason.message)
        } actions: {
            Button("Back to what I came for", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("dismissBlock")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .accessibilityIdentifier("blockedView")
    }
}

struct LoadErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't load the page", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
```

- [ ] **Step 4: Create the caught-up panel**

The panel is 2000 points tall on purpose: it is placed at the cutoff position and must cover everything below it.

`FocusFeed/UI/CaughtUpPanel.swift`

```swift
import SwiftUI

struct CaughtUpPanel: View {
    let extendable: Bool
    let onExtend: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(extendable ? "That's one page" : "You're caught up")
                .font(.headline)
            Text(extendable ? "Refine the search, or load one more page on purpose." : "Nothing newer than this. Go do something else.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if extendable {
                Button("Show one more page", action: onExtend)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("extendCutoff")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 2000, alignment: .top)
        .background(.background)
        .accessibilityIdentifier("caughtUpPanel")
    }
}
```

- [ ] **Step 5: Create the Filters sheet**

`FocusFeed/UI/FilterStatsView.swift`

```swift
import SwiftUI

struct FilterStatsView: View {
    let session: BrowserSession
    let onSaveSnapshot: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var savedSnapshot = false

    private func rows(_ counts: [String: Int]) -> [(name: String, count: Int)] {
        counts.sorted { $0.key < $1.key }.map { (name: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Leaking on this page") {
                    ForEach(rows(session.stats.leaks), id: \.name) { row in
                        LabeledContent(row.name, value: label(for: row.count))
                            .foregroundStyle(row.count == 0 ? Color.primary : Color.red)
                    }
                }
                Section("Hidden on this page") {
                    ForEach(rows(session.stats.hidden), id: \.name) { row in
                        LabeledContent(row.name, value: label(for: row.count))
                    }
                }
                Section {
                    Button(savedSnapshot ? "Snapshot saved" : "Save DOM snapshot") {
                        Task {
                            await onSaveSnapshot()
                            savedSnapshot = true
                        }
                    }
                    .accessibilityIdentifier("saveSnapshot")
                } footer: {
                    Text(session.currentURL?.absoluteString ?? "")
                }
            }
            .navigationTitle("\(session.profile.title) filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func label(for count: Int) -> String {
        count < 0 ? "invalid selector" : String(count)
    }
}
```

- [ ] **Step 6: Create the top bar**

`FocusFeed/UI/TopBar.swift`

```swift
import SwiftUI

struct TopBar: View {
    @Bindable var store: SessionStore

    @State private var showsStats = false

    private var session: BrowserSession { store.session(for: store.selected) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: session.goBack) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!session.canGoBack)
            .accessibilityIdentifier("back")

            Picker("Platform", selection: $store.selected) {
                ForEach(Platform.allCases) { platform in
                    Text(PlatformProfile.profile(for: platform).title).tag(platform)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("platformPicker")

            PageMenu(session: session, onShowStats: { showsStats = true })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .sheet(isPresented: $showsStats) {
            FilterStatsView(session: session, onSaveSnapshot: store.saveSnapshot)
        }
    }
}

struct PageMenu: View {
    let session: BrowserSession
    let onShowStats: () -> Void

    private var statsLabel: String {
        let stats = session.stats
        return stats.leakTotal > 0 ? "Filters: \(stats.leakTotal) leaking" : "Filters: \(stats.hiddenTotal) hidden"
    }

    private var statsIcon: String {
        session.stats.leakTotal > 0 ? "exclamationmark.triangle" : "line.3.horizontal.decrease.circle"
    }

    var body: some View {
        Menu {
            Button("Reload", systemImage: "arrow.clockwise", action: session.reload)
            Button("Feed", systemImage: "house", action: session.goHome)
            Button("Forward", systemImage: "chevron.forward", action: session.goForward)
                .disabled(!session.canGoForward)
            Divider()
            Button(statsLabel, systemImage: statsIcon, action: onShowStats)
        } label: {
            Image(systemName: session.stats.leakTotal > 0 ? "exclamationmark.circle" : "ellipsis.circle")
        }
        .accessibilityIdentifier("pageMenu")
    }
}
```

- [ ] **Step 7: Create the browser screen**

`FocusFeed/UI/BrowserScreen.swift`

```swift
import SwiftUI

struct BrowserScreen: View {
    @Bindable var session: BrowserSession

    var body: some View {
        WebViewContainer(webView: session.webView)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) { progressBar }
            .overlay(alignment: .top) { cutoffPanel }
            .overlay { overlay }
    }

    @ViewBuilder
    private var progressBar: some View {
        if session.isLoading {
            ProgressView(value: session.progress)
                .progressViewStyle(.linear)
        }
    }

    @ViewBuilder
    private var cutoffPanel: some View {
        if let top = session.cutoffPanelTop, let cutoff = session.cutoff {
            CaughtUpPanel(extendable: cutoff.extendable, onExtend: session.extendCutoff)
                .offset(y: top)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if let reason = session.blockReason {
            BlockedView(reason: reason, onDismiss: session.dismissBlock)
        } else if let message = session.loadError {
            LoadErrorView(message: message, onRetry: session.reload)
        }
    }
}
```

- [ ] **Step 8: Replace the placeholder root view**

All created sessions stay in the view tree; only the selected one is visible and touchable.

`FocusFeed/App/RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    @State private var store = SessionStore()

    var body: some View {
        VStack(spacing: 0) {
            TopBar(store: store)
            ZStack {
                ForEach(store.sessions) { session in
                    BrowserScreen(session: session)
                        .opacity(session.id == store.selected ? 1 : 0)
                        .allowsHitTesting(session.id == store.selected)
                }
            }
        }
        .onAppear { store.apply(LaunchOptions()) }
        .sheet(item: $store.externalPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
    }
}
```

- [ ] **Step 9: Build and run the unit tests**

```bash
make test
```

Expected: `Executed 38 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add FocusFeed
git commit -m "feat: app shell with top bar, blocked screen, caught-up panel and filters sheet"
```

---

### Task 6: UI smoke tests

**Files:**
- Replace: `FocusFeedUITests/SmokeUITests.swift`

- [ ] **Step 1: Replace the test file**

`FocusFeedUITests/SmokeUITests.swift`

```swift
import XCTest

final class SmokeUITests: XCUITestCase {
    func testLaunchShowsPlatformPickerAndControls() {
        XCTAssertTrue(app.segmentedControls["platformPicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["back"].exists)
        XCTAssertTrue(app.buttons["pageMenu"].exists)
    }

    func testSwitchingPlatformsKeepsControlsVisible() {
        let picker = app.segmentedControls["platformPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons["X"].tap()
        XCTAssertTrue(picker.buttons["X"].isSelected)
        picker.buttons["Instagram"].tap()
        XCTAssertTrue(picker.buttons["Instagram"].isSelected)
    }
}

class XCUITestCase: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }
}
```

- [ ] **Step 2: Run**

```bash
make uitest
```

Expected: `Executed 2 tests, with 0 failures`, `** TEST SUCCEEDED **`. The simulator loads the real sites while this runs; it needs internet but no login.

- [ ] **Step 3: Commit**

```bash
git add FocusFeedUITests
git commit -m "test: UI smoke tests for the shell"
```

---

### Task 7: Live probe

**Files:**
- Create: `scripts/live_probe.sh`

- [ ] **Step 1: Create the script**

`scripts/live_probe.sh`

```bash
#!/bin/zsh
set -euo pipefail

PLATFORM=${1:?usage: live_probe.sh <instagram|youtube|x> <url> [wait-seconds]}
URL=${2:?usage: live_probe.sh <instagram|youtube|x> <url> [wait-seconds]}
WAIT=${3:-10}
BUNDLE_ID=com.michalilski.focusfeed
SIMULATOR=${SIMULATOR:-iPhone 17 Pro}
OUT=build/probe

boot_simulator() {
  xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
  xcrun simctl bootstatus "$SIMULATOR" >/dev/null
}

install_app() {
  xcodebuild build -project FocusFeed.xcodeproj -scheme FocusFeed \
    -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath build -quiet
  xcrun simctl install "$SIMULATOR" build/Build/Products/Debug-iphonesimulator/FocusFeed.app
}

run_probe() {
  xcrun simctl terminate "$SIMULATOR" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID" -FFPlatform "$PLATFORM" -FFURL "$URL" -FFSnapshotAfter "$WAIT" >/dev/null
  sleep $((WAIT + 3))
}

collect() {
  local container
  container=$(xcrun simctl get_app_container "$SIMULATOR" "$BUNDLE_ID" data)
  mkdir -p "$OUT"
  xcrun simctl io "$SIMULATOR" screenshot "$OUT/$PLATFORM.png" >/dev/null 2>&1
  cp "$container/Documents/snapshots/$PLATFORM.html" "$container/Documents/snapshots/$PLATFORM.json" "$OUT/"
  cat "$OUT/$PLATFORM.json"
}

boot_simulator
install_app
run_probe
collect
```

```bash
chmod +x scripts/live_probe.sh
```

- [ ] **Step 2: Probe YouTube search**

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/results?search_query=lofi+music" 12
```

Expected in the printed report (numbers vary, the pattern must hold):

- `"url"` starts with `https://m.youtube.com/results?search_query=lofi+music`
- `"userAgent"` ends with `Version/26.0 Mobile/15E148 Safari/604.1`
- under `"leaks"`: `"shorts-link" : 0` and `"related-video" : 0`
- under `"hidden"`: `"shorts-nav-tab" : 1`, `"home-nav-tab" : 1`, and at least one of `shorts-grid-shelf`, `shorts-shelf`, `shorts-list-item` above 0

On 2026-10-01 this gave `shorts-grid-shelf: 4`. Look at `build/probe/youtube.png` with the Read tool: a YouTube consent dialog in Polish on top of dimmed search results is normal for a first run.

- [ ] **Step 3: Probe the watch page**

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/watch?v=jfKfPfyJRdk" 12
```

Expected: `"related-videos" : 1` under `hidden`, both leaks 0.

- [ ] **Step 4: Probe the Shorts rewrite and the home redirect**

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/shorts/aaaaaaaaaaa" 8 | grep '"url"'
./scripts/live_probe.sh youtube "https://m.youtube.com/" 8 | grep '"url"'
```

Expected: the first URL contains `/watch?v=aaaaaaaaaaa`. The second contains `feed/subscriptions`, either directly or inside a `consent.youtube.com/…continue=…feed%2Fsubscriptions…` URL.

- [ ] **Step 5: Probe a blocked page and look at it**

```bash
./scripts/live_probe.sh youtube "https://m.youtube.com/feed/trending" 6
```

Open `build/probe/youtube.png` with the Read tool. Expected: the "Recommendations are off" card with a leaf icon and the button "Back to what I came for", under the top bar.

- [ ] **Step 6: Commit**

```bash
git add scripts/live_probe.sh
git commit -m "feat: live probe script"
```

---

### Task 8: Look at it in the simulator (USER, optional but recommended)

- [ ] **Step 1:** Run `make sim`. In the simulator: dismiss the YouTube consent dialog, search for something, open a video, go back with the back button and with a swipe from the left edge, pull down to reload, open the menu, open Filters, switch to Instagram and X (login pages) and back to YouTube. YouTube must still be where you left it.
- [ ] **Step 2:** In YouTube search results, scroll down. After roughly seven screens the "That's one page" panel must slide in and scrolling must stop. "Show one more page" must let you scroll one more chunk.
- [ ] **Step 3:** Report anything that looks or feels wrong. Record it in the changelog under "Known gaps"; UX fixes are collected in phase 7.

---

### Task 9: First install on the iPhone (USER + agent)

- [ ] **Step 1 (USER):** Plug in the phone and unlock it.

- [ ] **Step 2: Check the phone is reachable**

```bash
xcrun devicectl list devices
```

Expected: `iPhone (Michał) … available (paired)`.

- [ ] **Step 3: Build, sign, install, launch**

```bash
make audit && make device
```

Expected: the build finishes without `error:` lines, then `App installed:` with the bundle ID, then `Launched application`. The first time, Xcode creates a provisioning profile, which can take a minute.

If it fails:

| Message | Fix |
| --- | --- |
| `No Account for Team "N5H5R9A2K2"` or `No profiles for 'com.michalilski.focusfeed' were found` | USER: open Xcode → Settings → Accounts, sign in to the Apple ID again, then rerun |
| Launch fails with a message about an untrusted developer or invalid code signature | USER: on the phone, Settings → General → VPN & Device Management → trust the developer, then rerun `make device` |
| `The device is locked` or `device is not connected` | USER: unlock the phone, check the cable |
| `Developer Mode disabled` | USER: Settings → Privacy & Security → Developer Mode → on, restart the phone |
| Device support files being prepared / "preparing device for development" | Wait and rerun; happens once after an iOS update |

- [ ] **Step 4 (USER):** On the phone, check that FocusFeed opens, the three platforms load their sites, and the layout respects the Dynamic Island and the home indicator. Do not log in yet; logins are the first task of phases 4, 5 and 6.

- [ ] **Step 5: Update the changelog and commit**

Set phase 3 to "done", note the install date (the build expires 7 days later), list anything found in tasks 8 and 9.

```bash
git add docs/plan/changelog.md
git commit -m "docs: phase 3 complete"
```
