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
    @ObservationIgnored private var reelGuard = ReelChainGuard()
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
        let decision = reelGuard.allows(url, isClientSide: isClientSide) ? guardedDecision(for: url) : .block(ReelChainGuard.reason)
        switch decision {
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
