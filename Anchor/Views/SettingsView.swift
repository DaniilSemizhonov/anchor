import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Environment(Updater.self) private var updater
    @AppStorage(SettingsKeys.autoCheckUpdates) private var autoCheckUpdates = true
    @AppStorage(SettingsKeys.includeBeta) private var includeBeta = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemNote: String?

    var body: some View {
        Form {
            Section("Общие") {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginItemNote {
                    Text(loginItemNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Обновления") {
                LabeledContent("Версия", value: updater.currentVersion.description)
                Toggle("Проверять автоматически", isOn: $autoCheckUpdates)
                Toggle("Получать бета-версии", isOn: $includeBeta)
                UpdateStatusView()
            }

            Section {
                Link("Anchor на GitHub", destination: URL(string: "https://github.com/DaniilSemizhonov/anchor")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemNote = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        if status == .requiresApproval {
            loginItemNote = "Разрешите Anchor в «Системные настройки → Основные → Объекты входа»."
        }
    }
}

private struct UpdateStatusView: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        switch updater.status {
        case .checking:
            HStack {
                ProgressView().controlSize(.small)
                Text("Проверяю…").foregroundStyle(.secondary)
            }
        case .installing:
            HStack {
                ProgressView().controlSize(.small)
                Text("Скачиваю и устанавливаю, Anchor перезапустится…").foregroundStyle(.secondary)
            }
        case .available(let release):
            VStack(alignment: .leading, spacing: 8) {
                Text("Доступна версия \(release.version.description)").font(.headline)
                if !release.notes.isEmpty {
                    Text(release.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                }
                HStack {
                    Button("Установить и перезапустить") { updater.install(release) }
                        .buttonStyle(.borderedProminent)
                    Link("Что нового", destination: release.pageURL)
                }
            }
        case .idle, .upToDate, .failed:
            HStack {
                Button("Проверить обновления") { updater.check() }
                switch updater.status {
                case .upToDate:
                    Text("Установлена последняя версия").foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message).foregroundStyle(.red)
                default:
                    EmptyView()
                }
            }
        }
    }
}
