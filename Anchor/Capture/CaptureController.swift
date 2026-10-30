import AnchorCore
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
    private var mode = Mode.task
    private var keyMonitor: Any?

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
        self.mode = mode
        installKeyMonitor()
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.onResignKey = nil
        panel.orderOut(nil)
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: - Клавиши

    /// Return, Tab и Esc ловим до поля ввода: многострочное поле SwiftUI иногда съедало
    /// Return, и задача не добавлялась. Текст берём прямо из редактора поля — он всегда актуален.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel else { return false }
        let editor = panel.firstResponder as? NSTextView
        let text = editor?.string ?? ""
        let flags = event.modifierFlags

        switch event.keyCode {
        case 36, 76: // Return, Enter
            if flags.contains(.shift) {
                editor?.insertNewlineIgnoringFieldEditor(nil)
            } else {
                submit(text, makeCurrent: flags.contains(.command))
            }
            return true
        case 48 where mode == .task && !flags.contains(.shift): // Tab — в парковку
            state.park(text)
            close()
            return true
        case 53: // Esc
            close()
            return true
        default:
            return false
        }
    }

    private func submit(_ text: String, makeCurrent: Bool) {
        switch mode {
        case .task:
            guard !QuickCaptureParser().parse(text, today: state.today).title.isEmpty else { return }
            withAnimation(.snappy) { state.capture(text, makeCurrent: makeCurrent) }
        case .crumb:
            state.addCrumb(text)
        }
        close()
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
