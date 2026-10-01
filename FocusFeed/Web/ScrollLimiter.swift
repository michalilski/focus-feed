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
