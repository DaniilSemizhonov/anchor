import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private static let autosaveName = "AnchorPanel"
    private let panel = FloatingPanel()

    init(state: AppState) {
        let hosting = NSHostingController(rootView: PanelRootView().environment(state))
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting

        if !panel.setFrameUsingName(Self.autosaveName) {
            placeAtTopCenter()
        }
        panel.setFrameAutosaveName(Self.autosaveName)
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

    private func placeAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.maxY - 12))
    }
}
