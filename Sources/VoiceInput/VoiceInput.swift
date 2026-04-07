import AppKit

@main
struct VoiceInput {
    static func main() {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) {
            NSApplication.shared.run()
        }
    }
}
