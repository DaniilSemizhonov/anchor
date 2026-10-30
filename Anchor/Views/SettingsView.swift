import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    enum Tab: String, CaseIterable, Identifiable {
        case general, appearance, shortcuts, updates

        var id: Self { self }

        var title: String {
            switch self {
            case .general: "Основные"
            case .appearance: "Вид"
            case .shortcuts: "Клавиши"
            case .updates: "Обновления"
            }
        }
    }

    /// `--settings-tab=appearance` — открыть на нужной вкладке (для скриншотов в CI).
    @State private var tab: Tab = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--settings-tab=") }
        .flatMap { Tab(rawValue: String($0.dropFirst("--settings-tab=".count))) } ?? .general

    var body: some View {
        // Свой переключатель вместо TabView: на macOS 27 вкладки TabView в этом окне
        // то уезжали в меню тулбара, то сплющивались.
        VStack(spacing: 0) {
            Picker("Раздел", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 16)

            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            case .shortcuts: ShortcutSettings()
            case .updates: UpdateSettings()
            }
        }
        .frame(width: 480, height: 560)
    }
}

// MARK: - Основные

private struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemNote: String?

    var body: some View {
        Form {
            Section {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginItemNote {
                    Text(loginItemNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ObsidianSettings()
            Section {
                Link("Anchor на GitHub", destination: URL(string: "https://github.com/DaniilSemizhonov/anchor")!)
            }
        }
        .formStyle(.grouped)
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

// MARK: - Obsidian

private struct ObsidianSettings: View {
    @Environment(VaultSync.self) private var vault
    @AppStorage(ObsidianKeys.vaultPath) private var vaultPath = ""
    @AppStorage(ObsidianKeys.syncEnabled) private var syncEnabled = false
    @AppStorage(ObsidianKeys.taskTag) private var taskTag = ""

    private var looksLikeVault: Bool {
        FileManager.default.fileExists(atPath: (vaultPath as NSString).appendingPathComponent(".obsidian"))
    }

    var body: some View {
        Section {
            LabeledContent("Хранилище") {
                HStack {
                    Text(vaultPath.isEmpty ? "Не выбрано" : (vaultPath as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(vaultPath.isEmpty ? .secondary : .primary)
                        .help(vaultPath)
                    Button("Выбрать…", action: chooseVault)
                    if !vaultPath.isEmpty {
                        Button("Убрать") {
                            vaultPath = ""
                            syncEnabled = false
                            vault.configure()
                        }
                    }
                }
            }
            if !vaultPath.isEmpty {
                if looksLikeVault {
                    Label("Хранилище найдено", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Label("Нет папки .obsidian — это точно хранилище?", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Toggle("Синхронизировать задачи", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { vault.configure() }
                TextField("Тег для Tasks", text: $taskTag, prompt: Text("без тега"))
                    .onSubmit { vault.configure() }
                status
            }
        } header: {
            Text("Obsidian")
        } footer: {
            Text("Задачи хранятся в «Anchor/Задачи.md» в формате плагина Tasks, мысли — в «Anchor/Парковка.md». Если у Tasks задан глобальный фильтр (например, #task), впишите этот тег — Anchor будет ставить его сам.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch vault.status {
        case .off:
            EmptyView()
        case .synced(let date):
            Text("Синхронизировано в \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать"
        panel.message = "Папка хранилища Obsidian"
        if !vaultPath.isEmpty { panel.directoryURL = URL(fileURLWithPath: vaultPath) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vaultPath = url.path
        vault.configure()
    }
}

// MARK: - Вид

private struct AppearanceSettings: View {
    @Environment(AppState.self) private var state
    @State private var previewGestures: GestureController?

    @AppStorage(AppearanceKeys.style) private var style = PanelStyle.glass
    @AppStorage(AppearanceKeys.color) private var colorHex = PanelDefaults.color
    @AppStorage(AppearanceKeys.opacity) private var opacity = PanelDefaults.opacity
    @AppStorage(AppearanceKeys.theme) private var theme = PanelTheme.auto
    @AppStorage(AppearanceKeys.width) private var width = PanelDefaults.width
    @AppStorage(AppearanceKeys.textSize) private var textSize = PanelTextSize.regular
    @AppStorage(AppearanceKeys.accent) private var accentHex = ""
    @AppStorage(AppearanceKeys.showTimer) private var showTimer = true
    @AppStorage(AppearanceKeys.showStep) private var showStep = true
    @AppStorage(AppearanceKeys.showAddStep) private var showAddStep = true

    private let presets = ["#5B8DEF", "#2E7D5B", "#8E5BEF", "#E86A5B", "#F2B544", "#2B2D33"]

    var body: some View {
        Form {
            Section {
                preview
            }

            Section("Фон") {
                Picker("Стиль", selection: $style) {
                    ForEach(PanelStyle.allCases) { Text($0.title).tag($0) }
                }
                if style.usesColor {
                    HStack {
                        ColorPicker("Цвет", selection: colorBinding($colorHex, fallback: .blue), supportsOpacity: false)
                        Spacer()
                        ForEach(presets, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(.primary.opacity(colorHex == hex ? 0.8 : 0), lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Slider(value: $opacity, in: 0.2...1) { Text("Насыщенность") }
                }
                Picker("Тема", selection: $theme) {
                    ForEach(PanelTheme.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Панель") {
                Slider(value: $width, in: PanelDefaults.widthRange, step: 10) { Text("Ширина") }
                Picker("Размер текста", selection: $textSize) {
                    ForEach(PanelTextSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Показывать следующий шаг", isOn: $showStep)
                Toggle("Показывать таймер", isOn: $showTimer)
                Toggle("Показывать поле «+ шаг»", isOn: $showAddStep)
                HStack {
                    ColorPicker("Акцентный цвет", selection: colorBinding($accentHex, fallback: .accentColor), supportsOpacity: false)
                    if !accentHex.isEmpty {
                        Button("Системный") { accentHex = "" }
                    }
                }
            }

            Section {
                Button("Сбросить оформление") {
                    AppearanceKeys.all.forEach { UserDefaults.standard.removeObject(forKey: $0) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if previewGestures == nil { previewGestures = GestureController(state: state) }
        }
    }

    /// Таблетка с текущими настройками — как она выглядит на экране.
    @ViewBuilder
    private var preview: some View {
        if let previewGestures {
            HStack {
                Spacer()
                PillView()
                    .frame(width: width)
                    .panelBackground()
                    .environment(previewGestures)
                    .allowsHitTesting(false)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [.indigo.opacity(0.5), .orange.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    private func colorBinding(_ hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) ?? fallback },
            set: { hex.wrappedValue = $0.hex }
        )
    }
}

// MARK: - Клавиши

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Быстрый ввод задачи", name: .quickCapture)
                KeyboardShortcuts.Recorder("Где остановился", name: .leaveCrumb)
                KeyboardShortcuts.Recorder("Шаг готов", name: .completeStep)
                KeyboardShortcuts.Recorder("Показать или спрятать панель", name: .togglePanel)
            } footer: {
                Text("Сочетания работают в любом приложении. macOS не разрешает глобальные сочетания только с ⌥ или ⌥⇧ — добавьте ⌃ или ⌘.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Обновления

private struct UpdateSettings: View {
    @Environment(Updater.self) private var updater
    @AppStorage(SettingsKeys.autoCheckUpdates) private var autoCheckUpdates = true
    @AppStorage(SettingsKeys.includeBeta) private var includeBeta = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Версия", value: updater.currentVersion.description)
                Toggle("Проверять автоматически", isOn: $autoCheckUpdates)
                Toggle("Получать бета-версии", isOn: $includeBeta)
                UpdateStatusView()
            }
        }
        .formStyle(.grouped)
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
