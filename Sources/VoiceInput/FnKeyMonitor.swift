import AppKit
import Carbon

/// Global Fn key monitor via CGEvent tap. Suppresses Fn events so the system emoji picker does not open.
final class FnKeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnHeld = false

    func install() {
        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("VoiceInput: CGEvent tap creation failed — grant Accessibility permission.")
            return
        }

        tap = t
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
    }

    deinit {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let fnDown = event.flags.contains(.maskSecondaryFn)
            if fnDown != fnHeld {
                fnHeld = fnDown
                if fnDown {
                    DispatchQueue.main.async { self.onFnDown?() }
                } else {
                    DispatchQueue.main.async { self.onFnUp?() }
                }
                return nil
            }
        }

        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 63 {
                let down = type == .keyDown
                if down != fnHeld {
                    fnHeld = down
                    if down {
                        DispatchQueue.main.async { self.onFnDown?() }
                    } else {
                        DispatchQueue.main.async { self.onFnUp?() }
                    }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
