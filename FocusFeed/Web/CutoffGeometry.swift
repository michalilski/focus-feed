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
