import AppKit
import SwiftUI

/// Окно быстрого ввода по хоткею, как Spotlight: появляется поверх всего (и поверх фуллскрина),
/// забирает клавиатуру, не активируя приложение, и закрывается по Esc или клику мимо.
@MainActor
final class CaptureController {
    enum Mode {
        /// Новая задача (Tab — в парковку).
        case task
        /// «Где остановился» у текущей задачи.
        case crumb
    }

    private static let size = NSSize(width: 640, height: 320)

    private let state: AppState
    private var panel: CapturePanel?

    init(state: AppState) {
        self.state = state
    }

    func show(_ mode: Mode, text: String = "") {
        close()
        let panel = CapturePanel(size: Self.size)
        panel.onResignKey = { [weak self] in self?.close() }
        panel.contentView = NSHostingView(rootView: CaptureView(mode: mode, initialText: text) { [weak self] in
            self?.close()
        }
        .environment(state))

        // Экран, где курсор: там пользователь сейчас и смотрит.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(
                x: visible.midX - Self.size.width / 2,
                y: visible.maxY - visible.height * 0.22
            ))
        }
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.onResignKey = nil
        panel.orderOut(nil)
    }
}

final class CapturePanel: NSPanel {
    var onResignKey: (() -> Void)?

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
