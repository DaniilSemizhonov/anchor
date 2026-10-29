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
        // Клавиатуру забираем только при клике в поле ввода, иначе печать уходила бы в Anchor.
        becomesKeyOnlyIfNeeded = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        // Тень рисует SwiftUI у карточки: окно больше неё и прозрачное.
        hasShadow = false
        animationBehavior = .none
    }

    // Иначе в поле ввода нельзя печатать.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
