import SwiftUI

struct BrowserScreen: View {
    @Bindable var session: BrowserSession

    var body: some View {
        WebViewContainer(webView: session.webView)
            .overlay(alignment: .top) { cutoffPanel }
            .overlay(alignment: .top) { LoadingBar(isLoading: session.isLoading, progress: session.progress) }
            .overlay { overlay }
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

struct LoadingBar: View {
    let isLoading: Bool
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.primary.opacity(0.35))
                .frame(width: proxy.size.width * progress)
        }
        .frame(height: 2)
        .opacity(isLoading ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: progress)
        .animation(.easeOut(duration: 0.3), value: isLoading)
        .allowsHitTesting(false)
    }
}
