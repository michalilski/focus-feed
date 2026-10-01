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
        return handle(url, isClientSide: false) ? .allowWithoutTryingAppLink : .cancel
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
