import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private static let positionKey = "panelTopLeft"
    private let panel = FloatingPanel()
    private var moveObserver: NSObjectProtocol?

    init(state: AppState) {
        let hosting = NSHostingView(rootView: PanelRootView { [weak self] size in
            self?.resize(to: size)
        }.environment(state))
        // Размер окна задаём сами (см. resize): автоподгонка AppKit через ограничения
        // на macOS 27 уходила в бесконечную рекурсию раскладки.
        hosting.sizingOptions = []
        panel.contentView = hosting
        // Точную высоту выставит resize после первой раскладки.
        panel.setContentSize(NSSize(width: PanelRootView.width, height: 44))

        // Запоминаем верхний левый угол: стандартный autosave для окон без изменения
        // размера хранит нижний, и после перезапуска панель сползала.
        if let saved = UserDefaults.standard.string(forKey: Self.positionKey).map(NSPointFromString),
           NSScreen.screens.contains(where: { $0.frame.contains(NSPoint(x: saved.x + 1, y: saved.y - 1)) }) {
            panel.setFrameTopLeftPoint(saved)
        } else {
            placeAtTopCenter()
        }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.savePosition() }
        }
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

    /// Подгоняет окно под содержимое, держа на месте верхний левый угол — панель раскрывается вниз.
    /// Асинхронно, чтобы не менять размер окна посреди его же раскладки.
    private func resize(to size: CGSize) {
        let target = Self.rounded(size)
        guard target.width > 0, target.height > 0 else { return }
        Task { @MainActor [panel] in
            guard panel.frame.size != target else { return }
            let top = panel.frame.maxY
            panel.setFrame(NSRect(x: panel.frame.minX, y: top - target.height, width: target.width, height: target.height),
                           display: true)
            panel.invalidateShadow()
        }
    }

    private func savePosition() {
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        UserDefaults.standard.set(NSStringFromPoint(topLeft), forKey: Self.positionKey)
    }

    private static func rounded(_ size: CGSize) -> NSSize {
        NSSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    private func placeAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - PanelRootView.width / 2, y: visible.maxY - 12))
    }
}
