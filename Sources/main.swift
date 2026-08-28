import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // Keep a strong reference for the app's lifetime.
    objc_setAssociatedObject(app, "tyftrack.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
