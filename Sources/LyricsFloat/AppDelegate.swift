import AppKit
import SwiftUI
import Combine

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var controller: LyricsOverlayController?
    private var bag: Set<AnyCancellable> = []

    private var statusItem: NSStatusItem?
    private var lockItem: NSMenuItem?
    private var clickThroughItem: NSMenuItem?
    private var providerItem: NSMenuItem?
    private var themeItem: NSMenuItem?
    private var opacityItem: NSMenuItem?
    private var showPanelItem: NSMenuItem?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = LyricsOverlayController()
        self.controller = controller

        let contentView = LyricsOverlayView(controller: controller)
        let host = NSHostingView(rootView: contentView)

        let panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 300, width: 720, height: 240),
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
        panel.alphaValue = controller.opacity

        self.panel = panel
        controller.closeOverlayAction = { [weak self] in
            self?.hidePanel()
        }
        bindPanelState(controller: controller, panel: panel)
        configureStatusBar()
        refreshMenuState()

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    @MainActor
    private func bindPanelState(controller: LyricsOverlayController, panel: FloatingPanel) {
        controller.$isLocked
            .removeDuplicates()
            .sink { [weak self, weak panel] locked in
                guard let panel else { return }
                if locked {
                    panel.styleMask.remove(.resizable)
                    panel.isMovableByWindowBackground = false
                } else {
                    panel.styleMask.insert(.resizable)
                    panel.isMovableByWindowBackground = true
                }
                self?.refreshMenuState()
            }
            .store(in: &bag)

        controller.$isClickThrough
            .removeDuplicates()
            .sink { [weak self, weak panel] clickThrough in
                panel?.ignoresMouseEvents = clickThrough
                self?.refreshMenuState()
            }
            .store(in: &bag)

        controller.$opacity
            .removeDuplicates()
            .sink { [weak self, weak panel] opacity in
                panel?.alphaValue = opacity
                self?.refreshMenuState()
            }
            .store(in: &bag)

        controller.$theme
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshMenuState()
            }
            .store(in: &bag)

        controller.$useNeteaseProvider
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshMenuState()
            }
            .store(in: &bag)
    }

    @MainActor
    private func configureStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "LyricsFloat")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()

        let lockItem = NSMenuItem(title: "锁定窗口", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        self.lockItem = lockItem
        menu.addItem(lockItem)

        let clickItem = NSMenuItem(title: "点击穿透", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickItem.target = self
        self.clickThroughItem = clickItem
        menu.addItem(clickItem)

        let opacityItem = NSMenuItem(title: "切换透明度", action: #selector(cycleOpacity), keyEquivalent: "")
        opacityItem.target = self
        self.opacityItem = opacityItem
        menu.addItem(opacityItem)

        let themeItem = NSMenuItem(title: "切换主题", action: #selector(toggleTheme), keyEquivalent: "")
        themeItem.target = self
        self.themeItem = themeItem
        menu.addItem(themeItem)

        let showPanelItem = NSMenuItem(title: "显示悬浮窗", action: #selector(showPanel), keyEquivalent: "")
        showPanelItem.target = self
        self.showPanelItem = showPanelItem
        menu.addItem(showPanelItem)

        let providerItem = NSMenuItem(title: "启用网易云歌词", action: #selector(toggleProvider), keyEquivalent: "")
        providerItem.target = self
        self.providerItem = providerItem
        menu.addItem(providerItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 LyricsFloat", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        self.statusItem = item
    }

    @MainActor
    private func refreshMenuState() {
        guard let controller else { return }
        lockItem?.state = controller.isLocked ? .on : .off
        clickThroughItem?.state = controller.isClickThrough ? .on : .off
        providerItem?.state = controller.useNeteaseProvider ? .on : .off
        themeItem?.title = "切换主题（当前：\(controller.theme.displayName)）"
        opacityItem?.title = "切换透明度（当前：\(Int(controller.opacity * 100))%）"
        showPanelItem?.isHidden = panel?.isVisible == true
    }

    @MainActor @objc private func toggleLock() {
        controller?.toggleLock()
    }

    @MainActor @objc private func toggleClickThrough() {
        controller?.toggleClickThrough()
    }

    @MainActor @objc private func cycleOpacity() {
        controller?.cycleOpacity()
    }

    @MainActor @objc private func toggleTheme() {
        controller?.toggleTheme()
    }

    @MainActor @objc private func showPanel() {
        guard let panel else { return }
        panel.orderFrontRegardless()
        refreshMenuState()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor @objc private func toggleProvider() {
        controller?.toggleNeteaseProvider()
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @MainActor
    private func hidePanel() {
        panel?.orderOut(nil)
        refreshMenuState()
    }
}
