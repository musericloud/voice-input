import AppKit
import QuartzCore

enum RecordingOverlayState {
    case idle
    case recording
    case refining
}

final class RecordingOverlayPanel {
    private let panel: NSPanel
    private let rootView = NSView()
    private let effectView = NSVisualEffectView()
    private let waveformView = WaveformBarsView(frame: .zero)
    private let recordingDot = NSView(frame: .zero)
    private let textField = NSTextField(labelWithString: "")
    private var widthConstraint: NSLayoutConstraint!

    private let minTextWidth: CGFloat = 160
    private let maxTextWidth: CGFloat = 560
    private let capsuleHeight: CGFloat = 40
    private let cornerRadius: CGFloat = 20

    private static let accent = NSColor(red: 0.30, green: 0.82, blue: 1.0, alpha: 1.0)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.becomesKeyOnlyIfNeeded = false

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = false
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = Self.accent.withAlphaComponent(0.2).cgColor
        effectView.layer?.shadowColor = Self.accent.withAlphaComponent(0.3).cgColor
        effectView.layer?.shadowRadius = 12
        effectView.layer?.shadowOpacity = 0.6
        effectView.layer?.shadowOffset = .zero

        setupRecordingDot()

        textField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        textField.textColor = NSColor.white.withAlphaComponent(0.92)
        textField.backgroundColor = .clear
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 2
        textField.cell?.wraps = true

        let hStack = NSStackView(views: [recordingDot, waveformView, textField])
        hStack.orientation = .horizontal
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 6, left: 16, bottom: 6, right: 18)
        hStack.alignment = .centerY

        recordingDot.translatesAutoresizingMaskIntoConstraints = false
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recordingDot.widthAnchor.constraint(equalToConstant: 7),
            recordingDot.heightAnchor.constraint(equalToConstant: 7),
            waveformView.widthAnchor.constraint(equalToConstant: 34),
            waveformView.heightAnchor.constraint(equalToConstant: 26)
        ])

        widthConstraint = textField.widthAnchor.constraint(equalToConstant: minTextWidth)
        NSLayoutConstraint.activate([
            widthConstraint,
            textField.widthAnchor.constraint(lessThanOrEqualToConstant: maxTextWidth)
        ])

        rootView.translatesAutoresizingMaskIntoConstraints = false
        effectView.translatesAutoresizingMaskIntoConstraints = false
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let maskView = NSView()
        maskView.wantsLayer = true
        maskView.layer?.cornerRadius = cornerRadius
        maskView.layer?.cornerCurve = .continuous
        maskView.layer?.masksToBounds = true
        maskView.translatesAutoresizingMaskIntoConstraints = false
        maskView.addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: maskView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: maskView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: maskView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: maskView.bottomAnchor)
        ])

        rootView.addSubview(maskView)
        NSLayoutConstraint.activate([
            maskView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            maskView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            maskView.topAnchor.constraint(equalTo: rootView.topAnchor),
            maskView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
        effectView.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hStack.topAnchor.constraint(equalTo: effectView.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        panel.contentView = rootView
        panel.alphaValue = 0
    }

    private func setupRecordingDot() {
        recordingDot.wantsLayer = true
        recordingDot.layer?.cornerRadius = 3.5
        recordingDot.layer?.backgroundColor = Self.accent.cgColor
        recordingDot.layer?.shadowColor = Self.accent.cgColor
        recordingDot.layer?.shadowRadius = 4
        recordingDot.layer?.shadowOpacity = 0.7
        recordingDot.layer?.shadowOffset = .zero
    }

    private func startDotPulse() {
        let glow = CABasicAnimation(keyPath: "shadowRadius")
        glow.fromValue = 2
        glow.toValue = 7
        glow.duration = 1.0
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let fade = CABasicAnimation(keyPath: "shadowOpacity")
        fade.fromValue = 0.4
        fade.toValue = 0.9
        fade.duration = 1.0
        fade.autoreverses = true
        fade.repeatCount = .infinity
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        recordingDot.layer?.add(glow, forKey: "glow")
        recordingDot.layer?.add(fade, forKey: "fade")
    }

    private func stopDotPulse() {
        recordingDot.layer?.removeAllAnimations()
    }

    func show(initialText: String = "") {
        textField.stringValue = initialText
        updateTextWidth(animated: false)
        rootView.layoutSubtreeIfNeeded()

        effectView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.92, y: 0.92))
        positionPanel()

        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.2, 0.64, 1)
            panel.animator().alphaValue = 1
            effectView.layer?.setAffineTransform(.identity)
        }
    }

    func hide() {
        stopDotPulse()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            effectView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.94, y: 0.94))
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.effectView.layer?.setAffineTransform(.identity)
        }
    }

    func setState(_ state: RecordingOverlayState) {
        switch state {
        case .idle:
            break
        case .recording:
            recordingDot.isHidden = false
            waveformView.isHidden = false
            startDotPulse()
        case .refining:
            recordingDot.isHidden = true
            waveformView.isHidden = true
            stopDotPulse()
            textField.stringValue = "Refining..."
            updateTextWidth(animated: true)
        }
    }

    func updateTranscript(_ text: String) {
        textField.stringValue = text
        updateTextWidth(animated: true)
    }

    func updateWaveformLevels(_ levels: [Float]) {
        waveformView.setBarHeights(levels)
    }

    private func updateTextWidth(animated: Bool) {
        let s = textField.stringValue as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textField.font as Any
        ]
        let rect = s.boundingRect(
            with: NSSize(width: maxTextWidth, height: 1_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let w = min(max(ceil(rect.width) + 8, minTextWidth), maxTextWidth)

        let apply = {
            self.widthConstraint.constant = w
            self.rootView.layoutSubtreeIfNeeded()
            self.positionPanel()
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                apply()
            }
        } else {
            apply()
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        rootView.layoutSubtreeIfNeeded()
        let w = rootView.fittingSize.width
        let h = capsuleHeight
        let vf = screen.visibleFrame
        let x = vf.midX - w / 2
        let y = vf.minY + 16
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }
}
