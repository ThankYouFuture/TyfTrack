import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    var statusTimer: Timer?

    let settings = AppSettings.shared
    lazy var store = TimerStore(settings: settings)
    let cache = BexioCache()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

        setupPanel()
        setupStatusItem()
        showPanel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    // MARK: Panel

    private func setupPanel() {
        let content = ContentView()
            .environmentObject(store)
            .environmentObject(cache)
            .environmentObject(settings)

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 372, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered, defer: false)
        panel.title = "TyfTrack"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = NSHostingView(rootView: content)

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - 400, y: f.maxY - 580))
        }
        panel.setFrameAutosaveName("TyfTrackPanel")
    }

    func showPanel() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = Bundle.main.image(named: "logo-tyf") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeft
            } else {
                button.title = "⏱"
            }
            button.action = #selector(statusClicked)
            button.target = self
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatusTitle() }
        }
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        let running = store.timers.filter(\.isRunning)
        if let first = running.first {
            let extra = running.count > 1 ? " +\(running.count - 1)" : ""
            button.title = " " + formatHMS(first.elapsed) + extra
        } else if !store.timers.isEmpty {
            button.title = " ⏸ \(store.timers.count)"
        } else {
            button.title = ""
        }
    }

    @objc private func statusClicked() {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: panel.isVisible ? "Masquer TyfTrack" : "Afficher TyfTrack",
                                  action: #selector(menuTogglePanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        for t in store.timers {
            let state = t.isRunning ? "▶" : "⏸"
            let item = NSMenuItem(title: "\(state) \(t.displayTitle) — \(formatHMS(t.elapsed))",
                                  action: #selector(menuToggleTimer(_:)), keyEquivalent: "")
            item.representedObject = t.id.uuidString
            item.target = self
            menu.addItem(item)
        }
        if !store.timers.isEmpty { menu.addItem(.separator()) }

        let expressItem = NSMenuItem(title: "⚡ Chrono express", action: #selector(menuExpress), keyEquivalent: "n")
        expressItem.target = self
        menu.addItem(expressItem)

        if !store.recents.isEmpty {
            let recentMenu = NSMenu()
            for r in store.recents.prefix(3) {
                let title = r.projectName.isEmpty ? r.displayTitle : "\(r.displayTitle) — \(r.projectName)"
                let item = NSMenuItem(title: title, action: #selector(menuRestartRecent(_:)), keyEquivalent: "")
                item.representedObject = r.id.uuidString
                item.target = self
                recentMenu.addItem(item)
            }
            let recentItem = NSMenuItem(title: "↻ Reprendre", action: nil, keyEquivalent: "")
            recentItem.submenu = recentMenu
            menu.addItem(recentItem)
        }

        if store.runningCount > 0 {
            let pauseItem = NSMenuItem(title: "Tout mettre en pause", action: #selector(menuPauseAll), keyEquivalent: "")
            pauseItem.target = self
            menu.addItem(pauseItem)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quitter TyfTrack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuTogglePanel() { togglePanel() }
    @objc private func menuExpress() { store.addExpressTimer(); showPanel() }
    @objc private func menuPauseAll() { store.pauseAll(reason: .user) }
    @objc private func menuRestartRecent(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let id = UUID(uuidString: s),
              let r = store.recents.first(where: { $0.id == id }) else { return }
        store.restart(r)
        showPanel()
    }

    @objc private func menuToggleTimer(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let id = UUID(uuidString: s) else { return }
        store.toggle(id)
    }

    // MARK: URL scheme (tyftrack://) — used by Raccourcis / Siri

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              let host = url.host else { return }
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let note = params.first(where: { $0.name == "note" })?.value ?? ""

        switch host {
        case "start":
            store.addExpressTimer(note: note)
            showPanel()
        case "pause":
            store.pauseAll(reason: .user)
        case "resume":
            for t in store.timers where !t.isRunning { store.resume(t.id) }
        case "show":
            showPanel()
        default:
            break
        }
    }
}
