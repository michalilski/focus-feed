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
