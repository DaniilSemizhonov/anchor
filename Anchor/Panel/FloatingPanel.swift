import AppKit

/// Окно поверх всех окон и полноэкранных приложений, которое не отбирает фокус.
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .none
    }

    // Иначе в поле ввода нельзя печатать.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// При изменении размера держим на месте верхний левый угол, чтобы панель раскрывалась вниз.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if frame.size != .zero, rect.size != frame.size, rect.origin == frame.origin {
            rect.origin.y = frame.maxY - rect.height
        }
        super.setFrame(rect, display: flag)
        invalidateShadow()
    }
}
