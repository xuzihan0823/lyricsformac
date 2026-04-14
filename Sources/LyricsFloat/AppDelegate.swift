import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var controller: LyricsOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = LyricsOverlayController()
        self.controller = controller

        let contentView = LyricsOverlayView(controller: controller)
        let host = NSHostingView(rootView: contentView)

        let panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 300, width: 680, height: 220),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }
}
