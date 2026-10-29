import SwiftUI

@main
struct AnchorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Anchor", systemImage: "scope") {
            Button("Показать или спрятать панель") { appDelegate.togglePanel() }
            Divider()
            Button("Выйти из Anchor") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var state = AppState.makeDefault()
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PanelController(state: state)
        controller.show()
        panelController = controller
    }

    func togglePanel() {
        panelController?.toggle()
    }
}
