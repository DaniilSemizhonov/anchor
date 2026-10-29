import AppKit
import SwiftUI

/// Окно панели постоянного размера и прозрачное: меняется только карточка внутри, поэтому
/// анимация не дёргается. Вне карточки окно пропускает клики насквозь, наведение отслеживаем сами.
@MainActor
final class PanelController {
    private static let positionKey = "panelTopLeft"
    private static let windowSize = NSSize(
        width: PanelRootView.width + 2 * PanelRootView.margin,
        height: PanelRootView.maxHeight
    )

    private let panel = FloatingPanel()
    private let state: AppState
    /// Карточка в координатах окна (начало — сверху слева).
    private var cardFrame: CGRect = .zero
    private var moveObserver: NSObjectProtocol?
    private var mouseTimer: Timer?
    private var hoverChange: Task<Void, Never>?
    private var pendingHover = false

    init(state: AppState) {
        self.state = state
        let hosting = NSHostingView(rootView: PanelRootView { [weak self] frame in
            self?.cardFrame = frame
        }.environment(state))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setContentSize(Self.windowSize)
        panel.ignoresMouseEvents = true

        // Запоминаем верхний левый угол: стандартный autosave для окон без изменения
        // размера хранит нижний, и после перезапуска панель сползала.
        if let saved = UserDefaults.standard.string(forKey: Self.positionKey).map(NSPointFromString),
           NSScreen.screens.contains(where: {
               $0.frame.contains(NSPoint(x: saved.x + PanelRootView.margin + 1, y: saved.y - PanelRootView.margin - 1))
           }) {
            panel.setFrameTopLeftPoint(saved)
        } else {
            placeAtTopCenter()
        }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.savePosition() }
        }

        // Опрос курсора надёжнее событий: окно не активно и вне карточки событий не получает.
        let timer = Timer(timeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    private func trackMouse() {
        guard panel.isVisible, cardFrame.width > 0 else { return }
        let card = NSRect(
            x: panel.frame.minX + cardFrame.minX,
            y: panel.frame.maxY - cardFrame.maxY,
            width: cardFrame.width,
            height: cardFrame.height
        )
        let inside = card.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }
        setHovering(inside)
    }

    /// Раскрываемся с небольшой задержкой, сворачиваемся с чуть большей — чтобы панель
    /// не мигала, когда курсор проходит мимо.
    private func setHovering(_ hovering: Bool) {
        guard hovering != pendingHover else { return }
        pendingHover = hovering
        hoverChange?.cancel()
        hoverChange = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(hovering ? 120 : 350))
            guard !Task.isCancelled, let self else { return }
            state.isHovering = hovering
        }
    }

    private func savePosition() {
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        UserDefaults.standard.set(NSStringFromPoint(topLeft), forKey: Self.positionKey)
    }

    private func placeAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - Self.windowSize.width / 2, y: visible.maxY))
    }
}
