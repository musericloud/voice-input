import AppKit
import QuartzCore

final class WaveformBarsView: NSView {
    private let barLayers: [CALayer]
    private let barWidth: CGFloat = 2.5
    private let gap: CGFloat = 2
    private let baseHeight: CGFloat = 4
    private let dynamicRange: CGFloat = 20

    private static let accentColor = NSColor(red: 0.30, green: 0.82, blue: 1.0, alpha: 1.0)

    private static let barColors: [NSColor] = [
        NSColor(red: 0.28, green: 0.82, blue: 0.96, alpha: 0.75),
        NSColor(red: 0.32, green: 0.76, blue: 1.00, alpha: 0.82),
        NSColor(red: 0.38, green: 0.68, blue: 1.00, alpha: 0.90),
        NSColor(red: 0.45, green: 0.58, blue: 1.00, alpha: 1.00),
        NSColor(red: 0.38, green: 0.68, blue: 1.00, alpha: 0.90),
        NSColor(red: 0.32, green: 0.76, blue: 1.00, alpha: 0.82),
        NSColor(red: 0.28, green: 0.82, blue: 0.96, alpha: 0.75),
    ]

    override init(frame frameRect: NSRect) {
        barLayers = Self.barColors.map { color in
            let l = CALayer()
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            l.cornerRadius = 1.25
            l.backgroundColor = color.cgColor
            l.shadowColor = Self.accentColor.withAlphaComponent(0.5).cgColor
            l.shadowRadius = 3
            l.shadowOpacity = 0
            l.shadowOffset = .zero
            return l
        }
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for l in barLayers { layer?.addSublayer(l) }
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let count = CGFloat(barLayers.count)
        let totalW = count * barWidth + (count - 1) * gap
        var x = (bounds.width - totalW) / 2 + barWidth / 2
        let cy = bounds.midY
        for l in barLayers {
            l.position = CGPoint(x: x, y: cy)
            x += barWidth + gap
        }
    }

    func setBarHeights(_ normalized: [Float]) {
        guard normalized.count == barLayers.count else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in 0 ..< barLayers.count {
            let v = normalized[i]
            let h = baseHeight + CGFloat(v) * dynamicRange
            barLayers[i].bounds = CGRect(x: 0, y: 0, width: barWidth, height: h)
            barLayers[i].shadowOpacity = Float(min(1.0, v * 1.5))
        }
        CATransaction.commit()
    }
}
