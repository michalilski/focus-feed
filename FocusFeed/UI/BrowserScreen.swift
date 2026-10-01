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
