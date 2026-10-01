import WebKit

final class FilterBridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "focusFeed"

    var onMessage: ((FilterMessage) -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let parsed = FilterMessage(body: message.body) else { return }
        onMessage?(parsed)
    }
}
