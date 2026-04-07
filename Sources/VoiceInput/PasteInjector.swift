import AppKit
import Carbon

enum PasteInjector {
    private typealias ItemSnapshot = [(NSPasteboard.PasteboardType, Data)]

    static func inject(_ text: String) {
        let pb = NSPasteboard.general
        let saved = snapshotPasteboard(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)

        let needsAscii = InputSourceManager.isActiveCJKInputMethod()
        if needsAscii {
            InputSourceManager.selectASCIILayout()
        }

        let pasteDelay: TimeInterval = needsAscii ? 0.08 : 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            simulateCmdV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if needsAscii {
                    InputSourceManager.restorePreviousInputSource()
                }
                restorePasteboard(pb, from: saved)
            }
        }
    }

    private static func snapshotPasteboard(_ pb: NSPasteboard) -> [ItemSnapshot] {
        var result: [ItemSnapshot] = []
        for item in pb.pasteboardItems ?? [] {
            var pairs: ItemSnapshot = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    pairs.append((type, data))
                }
            }
            if !pairs.isEmpty { result.append(pairs) }
        }
        return result
    }

    private static func restorePasteboard(_ pb: NSPasteboard, from snapshot: [ItemSnapshot]) {
        pb.clearContents()
        guard !snapshot.isEmpty else { return }
        var items: [NSPasteboardItem] = []
        for pairs in snapshot {
            let item = NSPasteboardItem()
            for (type, data) in pairs {
                item.setData(data, forType: type)
            }
            items.append(item)
        }
        pb.writeObjects(items)
    }

    private static func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
