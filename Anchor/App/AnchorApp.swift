import KeyboardShortcuts
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
                .environment(appDelegate.state)
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
        Button("Новая задача…") { appDelegate.showCapture(.task) }
        Button("Где остановился…") { appDelegate.showCapture(.crumb) }
        Button("Показать или спрятать панель") { appDelegate.togglePanel() }
        Divider()
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
    private lazy var capture = CaptureController(state: state)
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PanelController(state: state)
        controller.show()
        panelController = controller

        KeyboardShortcuts.onKeyDown(for: .quickCapture) { [weak self] in self?.showCapture(.task) }
        KeyboardShortcuts.onKeyDown(for: .leaveCrumb) { [weak self] in self?.showCapture(.crumb) }
        KeyboardShortcuts.onKeyDown(for: .completeStep) { [weak self] in
            withAnimation(.snappy) { self?.state.completeNextStepOrTask() }
        }
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in self?.togglePanel() }

        let arguments = ProcessInfo.processInfo.arguments
        if !arguments.contains("--demo") {
            updater.startAutomaticChecks()
        }
        // `--capture` — открыть быстрый ввод с примером (для скриншотов в CI).
        if arguments.contains("--capture") {
            showCapture(.task, text: "Доклад к пятнице #учёба !\nсобрать источники")
        }
    }

    func showCapture(_ mode: CaptureController.Mode, text: String = "") {
        capture.show(mode, text: text)
    }

    func togglePanel() {
        panelController?.toggle()
    }
}
