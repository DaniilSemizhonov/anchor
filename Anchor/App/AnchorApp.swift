import SwiftUI

@main
struct AnchorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Anchor", systemImage: "scope") {
            MenuContent(appDelegate: appDelegate)
                .environment(appDelegate.updater)
        }

        Window("Настройки Anchor", id: SettingsView.windowID) {
            SettingsView()
                .environment(appDelegate.updater)
        }
        .windowResizability(.contentSize)
        // `--settings` — открыть настройки сразу (для скриншотов в CI).
        .defaultLaunchBehavior(ProcessInfo.processInfo.arguments.contains("--settings") ? .presented : .suppressed)
    }
}

private struct MenuContent: View {
    let appDelegate: AppDelegate
    @Environment(Updater.self) private var updater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let release = updater.availableRelease {
            Button("Установить обновление \(release.version.description)") { updater.install(release) }
            Divider()
        }
        Button("Показать или спрятать панель") { appDelegate.togglePanel() }
        Button("Настройки…") {
            openWindow(id: SettingsView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Выйти из Anchor") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var state = AppState.makeDefault()
    private(set) lazy var updater = Updater()
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PanelController(state: state)
        controller.show()
        panelController = controller

        if !ProcessInfo.processInfo.arguments.contains("--demo") {
            updater.startAutomaticChecks()
        }
    }

    func togglePanel() {
        panelController?.toggle()
    }
}
