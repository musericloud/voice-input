import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let fnMonitor = FnKeyMonitor()
    private let recording = RecordingController()
    private var statusItem: NSStatusItem?
    private let settings = AppSettingsStore.shared
    private var llmSettingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "voiceInput.language": VoiceLanguage.chineseSimplified.rawValue,
            "voiceInput.llmEnabled": false,
            "voiceInput.apiBaseURL": "https://api.openai.com/v1",
            "voiceInput.model": "gpt-4o-mini"
        ])
        installMainMenu()
        setupMenuBar()
        fnMonitor.install()
        fnMonitor.onFnDown = { [weak self] in
            self?.recording.start()
        }
        fnMonitor.onFnUp = { [weak self] in
            self?.recording.stop()
        }
    }

    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let barW: CGFloat = 2
            let gap: CGFloat = 2
            let heights: [CGFloat] = [5, 9, 13, 8, 4]
            let count = CGFloat(heights.count)
            let totalW = count * barW + (count - 1) * gap
            var x = (rect.width - totalW) / 2
            let cy = rect.midY

            for h in heights {
                let r = NSRect(x: x, y: cy - h / 2, width: barW, height: h)
                NSBezierPath(roundedRect: r, xRadius: 1, yRadius: 1).fill()
                x += barW + gap
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = Self.makeMenuBarIcon()
        }

        let menu = NSMenu()
        menu.addItem(makeLanguageMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeLLMMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit VoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        refreshLanguageChecks()
    }

    private func makeLanguageMenuItem() -> NSMenuItem {
        let root = NSMenuItem(title: "Recognition Language", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for lang in VoiceLanguage.allCases {
            let mi = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = lang.rawValue
            mi.state = settings.voiceLanguage == lang ? .on : .off
            sub.addItem(mi)
        }
        root.submenu = sub
        return root
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = VoiceLanguage(rawValue: raw) else { return }
        settings.voiceLanguage = lang
        refreshLanguageChecks()
    }

    private func refreshLanguageChecks() {
        guard let menu = statusItem?.menu,
              let langRoot = menu.items.first(where: { $0.title == "Recognition Language" }),
              let sub = langRoot.submenu else { return }
        for item in sub.items {
            guard let raw = item.representedObject as? String,
                  let lang = VoiceLanguage(rawValue: raw) else { continue }
            item.state = settings.voiceLanguage == lang ? .on : .off
        }
    }

    private func makeLLMMenuItem() -> NSMenuItem {
        let root = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let toggle = NSMenuItem(title: "Enable Refinement", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = settings.llmRefinementEnabled ? .on : .off
        sub.addItem(toggle)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openLLMSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        sub.addItem(settingsItem)
        root.submenu = sub
        return root
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        settings.llmRefinementEnabled.toggle()
        sender.state = settings.llmRefinementEnabled ? .on : .off
    }

    @objc private func openLLMSettings(_ sender: Any?) {
        if llmSettingsWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "LLM Refinement"
            win.center()
            win.isReleasedWhenClosed = false
            llmSettingsWindow = win
        }
        let host = NSHostingController(rootView: LLMSettingsView(onClose: { [weak self] in
            self?.llmSettingsWindow?.close()
        }))
        llmSettingsWindow!.contentViewController = host
        llmSettingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
