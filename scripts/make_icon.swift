import AppKit

struct IconRenderer {
    let size: CGFloat = 1024

    func render() -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.current = context
        drawBackground()
        drawRings()
        context.flushGraphics()
        return bitmap.representation(using: .png, properties: [:])
    }

    private func drawBackground() {
        let colors = [NSColor(red: 0.10, green: 0.33, blue: 0.29, alpha: 1), NSColor(red: 0.20, green: 0.55, blue: 0.47, alpha: 1)]
        NSGradient(colors: colors)?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)
    }

    private func drawRings() {
        let center = NSPoint(x: size / 2, y: size / 2)
        for (radius, alpha) in [(330.0, 0.35), (220.0, 0.6)] {
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            ring.lineWidth = 44
            NSColor.white.withAlphaComponent(alpha).setStroke()
            ring.stroke()
        }
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 96, y: center.y - 96, width: 192, height: 192)).fill()
    }
}

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
guard let data = IconRenderer().render() else { fatalError("Could not render icon") }
try data.write(to: URL(fileURLWithPath: output))
