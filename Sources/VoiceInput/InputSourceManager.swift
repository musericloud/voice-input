import Carbon
import CoreFoundation

/// Temporarily switch to an English keyboard input source for reliable Cmd+V pasting when a CJK input method is active.
enum InputSourceManager {
    private static var savedInputSource: TISInputSource?

    static func isActiveCJKInputMethod() -> Bool {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return isCJKInputMethod(source)
    }

    private static func isCJKInputMethod(_ source: TISInputSource) -> Bool {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

        if id.hasPrefix("com.apple.keylayout.") { return false }

        let lower = id.lowercased()
        if lower.hasSuffix(".roman")
            || lower.hasSuffix(".abc")
            || lower.contains("alphanumeric") {
            return false
        }

        // Any active input method (Apple or third-party) that isn't in an
        // ASCII sub-mode may intercept Cmd+V. Temporarily switching to an
        // ASCII layout costs nothing visible, so we err on the safe side.
        return true
    }

    static func selectASCIILayout() {
        savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if let en = TISCopyInputSourceForLanguage("en-US" as CFString)?.takeRetainedValue() {
            TISSelectInputSource(en)
        } else if let en = TISCopyInputSourceForLanguage("en" as CFString)?.takeRetainedValue() {
            TISSelectInputSource(en)
        }
    }

    static func restorePreviousInputSource() {
        if let saved = savedInputSource {
            TISSelectInputSource(saved)
            savedInputSource = nil
        }
    }
}
