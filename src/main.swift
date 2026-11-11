import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // Accessory app: doesn't steal focus, doesn't show in dock, stays lightweight

let delegate = NotchWindowController()
app.delegate = delegate
app.run()
