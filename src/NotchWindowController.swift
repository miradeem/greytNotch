import AppKit
import SwiftUI

struct NotchGeometry {
    let collapsedRect: NSRect
    let expandedRect: NSRect
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchCenterX: CGFloat

    static func currentScreen() -> NSScreen {
        return NSScreen.screens.first { s in
            if #available(macOS 12.0, *) {
                return s.auxiliaryTopLeftArea != nil && s.auxiliaryTopRightArea != nil
            }
            return false
        } ?? NSScreen.main ?? NSScreen.screens.first!
    }

    static func get() -> NotchGeometry {
        let screen = currentScreen()
        let screenFrame = screen.frame
        let topY = screenFrame.origin.y + screenFrame.height

        var notchX: CGFloat
        var notchY: CGFloat
        var notchW: CGFloat
        var notchH: CGFloat

        if #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            notchX = leftArea.maxX
            notchW = rightArea.minX - leftArea.maxX
            notchH = topY - leftArea.minY
            notchY = leftArea.minY
        } else {
            notchW = 180.0
            notchH = 32.0
            notchX = screenFrame.origin.x + (screenFrame.width - notchW) / 2.0
            notchY = topY - notchH
        }

        let notchCenterX = notchX + (notchW / 2.0)
        let windowWidth: CGFloat = 460.0
        let expandedHeight: CGFloat = 215.0

        let collapsedRect = NSRect(
            x: notchX,
            y: notchY,
            width: notchW,
            height: notchH
        )

        let expandedX = round(notchCenterX - (windowWidth / 2.0))
        let expandedRect = NSRect(
            x: expandedX,
            y: topY - expandedHeight,
            width: windowWidth,
            height: expandedHeight
        )

        return NotchGeometry(
            collapsedRect: collapsedRect,
            expandedRect: expandedRect,
            notchWidth: notchW,
            notchHeight: notchH,
            notchCenterX: notchCenterX
        )
    }

    // STRICTLY inside the blacked out camera notch area and nowhere else!
    // NO top margin: the physical notch extends all the way to the top edge of the screen!
    static func isMouseInBlackedOutNotch(_ point: NSPoint) -> Bool {
        let geom = get()
        let notch = geom.collapsedRect
        let minX = notch.minX + 4.0
        let maxX = notch.maxX - 4.0
        // Physical notch vertically: strictly from bottom of notch (y >= notch.minY + 3)
        // all the way to the top edge of the display with NO top margin or ceiling!
        let minY = notch.minY + 3.0

        return point.x >= minX && point.x <= maxX && point.y >= minY
    }

    // Active zone for expanded card (including the notch and top of screen above it)
    // NO top margin: going all the way to the top of the notch keeps the card open!
    static func isMouseInExpandedCard(_ point: NSPoint) -> Bool {
        let geom = get()
        let cardWidth: CGFloat = 380.0
        let cardX = geom.notchCenterX - (cardWidth / 2.0)

        // Card width with 8pt active perimeter
        let minX = cardX - 8.0
        let maxX = cardX + cardWidth + 8.0
        // Card hangs ~138pt below the notch. Active all the way to the top edge of the screen!
        let minY = geom.collapsedRect.origin.y - 138.0

        return point.x >= minX && point.x <= maxX && point.y >= minY
    }
}

class HoverHostingView<Content: View>: NSHostingView<Content> {
    var islandState: IslandState!
    var onMouseEnterNotch: (() -> Void)?
    var onMouseLeaveCard: (() -> Void)?
    var onMouseInsideCard: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    let cardWidth: CGFloat = 380.0

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if islandState.isExpanded {
            let centerX = bounds.width / 2.0
            // When expanded: Capture clicks inside the visible card rect (width: 380)
            // Passes clicks through to underlying apps on the left/right/bottom shadow margins
            let cardRect = NSRect(
                x: centerX - (cardWidth / 2.0),
                y: 50,
                width: cardWidth,
                height: bounds.height - 50
            )
            if cardRect.contains(point) {
                return super.hitTest(point)
            }
            return nil
        } else {
            // When collapsed: the window frame is strictly the physical camera notch.
            return self
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let mouseScreen = NSEvent.mouseLocation

        if islandState.isExpanded {
            if NotchGeometry.isMouseInExpandedCard(mouseScreen) {
                onMouseInsideCard?()
            } else {
                onMouseLeaveCard?()
            }
        } else {
            // ONLY trigger if cursor is strictly inside the blacked out notch bezel!
            if NotchGeometry.isMouseInBlackedOutNotch(mouseScreen) {
                onMouseEnterNotch?()
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        let mouseScreen = NSEvent.mouseLocation
        if !islandState.isExpanded {
            if NotchGeometry.isMouseInBlackedOutNotch(mouseScreen) {
                onMouseEnterNotch?()
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        let mouseScreen = NSEvent.mouseLocation
        if islandState.isExpanded {
            // Only trigger collapse if mouse has actually moved outside the card / notch area!
            // If the mouse hits the top edge of the display inside the notch, do NOT collapse!
            if !NotchGeometry.isMouseInExpandedCard(mouseScreen) {
                onMouseLeaveCard?()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let mouseScreen = NSEvent.mouseLocation
        if !islandState.isExpanded {
            if NotchGeometry.isMouseInBlackedOutNotch(mouseScreen) {
                onMouseEnterNotch?()
            }
        } else {
            super.mouseDown(with: event)
        }
    }
}

class NotchWindowController: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var manager = AttendanceManager()
    let islandState = IslandState()

    private var collapseWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupScreenChangeObserver()
    }

    private func setupPanel() {
        let geom = NotchGeometry.get()

        panel = NSPanel(
            contentRect: geom.collapsedRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .mainMenu + 3 // Float above menu bar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let rootView = NotchView(
            manager: manager,
            islandState: islandState,
            notchHeight: geom.notchHeight,
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )

        let hostingView = HoverHostingView(rootView: rootView)
        hostingView.islandState = islandState
        hostingView.onMouseEnterNotch = { [weak self] in
            self?.handleMouseEnterNotch()
        }
        hostingView.onMouseInsideCard = { [weak self] in
            self?.handleMouseInsideCard()
        }
        hostingView.onMouseLeaveCard = { [weak self] in
            self?.handleMouseLeaveCard()
        }

        panel.contentView = hostingView
        panel.setFrame(geom.collapsedRect, display: true)
        panel.orderFrontRegardless()
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let geom = NotchGeometry.get()
            if self.islandState.isExpanded {
                self.panel.setFrame(geom.expandedRect, display: true)
            } else {
                self.panel.setFrame(geom.collapsedRect, display: true)
            }
        }
    }

    func handleMouseEnterNotch() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        let mouseScreen = NSEvent.mouseLocation
        // Double check: MUST be physically in the blacked out notch!
        guard NotchGeometry.isMouseInBlackedOutNotch(mouseScreen) else { return }

        let geom = NotchGeometry.get()
        if panel.frame != geom.expandedRect {
            panel.setFrame(geom.expandedRect, display: true)
        }

        if !islandState.isExpanded {
            withAnimation(islandState.selectedStyle.inAnimation) {
                self.islandState.isExpanded = true
            }
        }
    }

    func handleMouseInsideCard() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        if !islandState.isExpanded {
            let geom = NotchGeometry.get()
            if panel.frame != geom.expandedRect {
                panel.setFrame(geom.expandedRect, display: true)
            }
            withAnimation(islandState.selectedStyle.inAnimation) {
                self.islandState.isExpanded = true
            }
        }
    }

    func handleMouseLeaveCard() {
        guard !islandState.isPinned else { return }
        collapseWorkItem?.cancel()

        // 50ms exit debounce: ensure it was a deliberate move away
        let collapseItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.islandState.isPinned, self.islandState.isExpanded else { return }

            // Dynamic style retract animation with guaranteed completion callback
            withAnimation(self.islandState.selectedStyle.outAnimation) {
                self.islandState.isExpanded = false
            } completion: {
                guard !self.islandState.isExpanded, !self.islandState.isPinned else { return }
                let geom = NotchGeometry.get()
                // Frame is resized ONLY after the card has completely vanished!
                // Zero stutter to the right, zero jump!
                self.panel.setFrame(geom.collapsedRect, display: true)
            }
        }

        self.collapseWorkItem = collapseItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: collapseItem)
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
