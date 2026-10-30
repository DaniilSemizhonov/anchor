import AnchorCore
import Foundation
import Observation

enum ObsidianKeys {
    static let vaultPath = "obsidian.vaultPath"
    static let syncEnabled = "obsidian.syncEnabled"
    /// Тег, который нужен плагину Tasks как глобальный фильтр (например, `task`), без `#`.
    static let taskTag = "obsidian.taskTag"
}

/// Синхронизация с хранилищем Obsidian: задачи в `Anchor/Задачи.md` (формат Tasks),
/// мысли в `Anchor/Парковка.md`. Файл — источник правды: при каждом сохранении изменения
/// приложения сливаются с версией файла, а правки из Obsidian подхватываются опросом раз в 2 с.
@MainActor
@Observable
final class VaultSync {
    enum Status: Equatable {
        case off
        case synced(Date)
        case failed(String)
    }

    private(set) var status: Status = .off

    @ObservationIgnored private weak var state: AppState?
    @ObservationIgnored private var folder: URL?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var tag = ""
    /// Текст файлов при последней синхронизации и задачи из него — база для слияния.
    @ObservationIgnored private var tasksText: String?
    @ObservationIgnored private var baseTasks: [AnchorTask] = []
    @ObservationIgnored private var parkingText: String?
    @ObservationIgnored private var baseParked: [String] = []

    init(state: AppState) {
        self.state = state
    }

    var isActive: Bool { folder != nil }

    private var tasksURL: URL? { folder?.appending(path: "Задачи.md") }
    private var parkingURL: URL? { folder?.appending(path: "Парковка.md") }

    /// Перечитать настройки и включить или выключить синхронизацию.
    func configure() {
        stop()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: ObsidianKeys.syncEnabled),
              let path = defaults.string(forKey: ObsidianKeys.vaultPath), !path.isEmpty
        else { return }
        tag = (defaults.string(forKey: ObsidianKeys.taskTag) ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
        start(vault: URL(fileURLWithPath: path, isDirectory: true))
    }

    private func start(vault: URL) {
        guard let state else { return }
        let folder = vault.appending(path: "Anchor", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder

            // Задачи: есть файл — берём из него, нет — создаём из локальных.
            if let text = read(tasksURL) {
                loadTasks(text)
            } else {
                var doc = TasksDocument(markdown: Self.header(title: "Задачи Anchor", tags: ["task"]))
                doc.sync(with: state.tasks.map(withTag))
                try writeTasks(doc)
            }
            if let text = read(parkingURL) {
                loadParking(text)
            } else {
                var doc = ParkingDocument(markdown: Self.header(title: "Парковка Anchor", tags: []))
                doc.sync(with: state.parked.map(\.text))
                try writeParking(doc)
            }
            state.replaceFromVault(tasks: baseTasks.map(withoutTag), parked: baseParked)
            status = .synced(.now)
        } catch {
            fail(error)
            return
        }

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        folder = nil
        tasksText = nil
        parkingText = nil
        baseTasks = []
        baseParked = []
        status = .off
    }

    /// Вызывается при каждом сохранении состояния приложения.
    func write(tasks: [AnchorTask], parked: [String]) {
        guard isActive else { return }
        do {
            // Сливаем с текущим файлом, а не с нашей последней записью: вдруг его только что поменяли.
            let current = read(tasksURL) ?? tasksText ?? ""
            var doc = TasksDocument(markdown: current)
            doc.materializeIDs()
            doc.apply(changesFrom: baseTasks, to: tasks.map(withTag))
            try writeTasks(doc)

            let currentParking = read(parkingURL) ?? parkingText ?? ""
            var parking = ParkingDocument(markdown: currentParking)
            parking.sync(with: Self.merge(base: baseParked, ours: parked, theirs: parking.items))
            try writeParking(parking)

            // Если в файле были чужие правки, приложение должно их увидеть.
            if doc.tasks.map(withoutTag) != tasks || parking.items != parked {
                state?.replaceFromVault(tasks: doc.tasks.map(withoutTag), parked: parking.items)
            }
            status = .synced(.now)
        } catch {
            fail(error)
        }
    }

    // MARK: - Внешние изменения

    private func poll() {
        guard isActive, let state else { return }
        var changed = false
        if let text = read(tasksURL), text != tasksText {
            loadTasks(text)
            changed = true
        }
        if let text = read(parkingURL), text != parkingText {
            loadParking(text)
            changed = true
        }
        if changed {
            state.replaceFromVault(tasks: baseTasks.map(withoutTag), parked: baseParked)
            status = .synced(.now)
        }
    }

    private func loadTasks(_ text: String) {
        var doc = TasksDocument(markdown: text)
        if doc.hasUnsavedIDs {
            // Задачи, написанные руками, получают 🆔, чтобы не менять id между чтениями.
            doc.materializeIDs()
            do { try writeTasks(doc) } catch { fail(error) }
        } else {
            tasksText = text
            baseTasks = doc.tasks
        }
    }

    private func loadParking(_ text: String) {
        parkingText = text
        baseParked = ParkingDocument(markdown: text).items
    }

    // MARK: - Файлы

    private func read(_ url: URL?) -> String? {
        url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private func writeTasks(_ doc: TasksDocument) throws {
        let text = doc.render()
        if text != tasksText, let url = tasksURL {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        tasksText = text
        baseTasks = doc.tasks
    }

    private func writeParking(_ doc: ParkingDocument) throws {
        let text = doc.render()
        if text != parkingText, let url = parkingURL {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        parkingText = text
        baseParked = doc.items
    }

    private func fail(_ error: Error) {
        status = .failed(error.localizedDescription)
    }

    // MARK: - Тег для Tasks

    private func withTag(_ task: AnchorTask) -> AnchorTask {
        guard !tag.isEmpty, !task.tags.contains(tag) else { return task }
        var tagged = task
        tagged.tags.append(tag)
        return tagged
    }

    private func withoutTag(_ task: AnchorTask) -> AnchorTask {
        guard !tag.isEmpty else { return task }
        var plain = task
        plain.tags.removeAll { $0 == tag }
        return plain
    }

    // MARK: - Помощники

    /// Слияние списков мыслей: из файла убираем то, что удалили в приложении, и дописываем новое.
    static func merge(base: [String], ours: [String], theirs: [String]) -> [String] {
        let removed = Set(base).subtracting(ours)
        let added = ours.filter { !base.contains($0) && !theirs.contains($0) }
        return theirs.filter { !removed.contains($0) } + added
    }

    /// Frontmatter в стиле хранилища.
    static func header(title: String, tags: [String]) -> String {
        var lines = [
            "---",
            "title: \(title)",
            "created: \(LocalDate(Date()).iso)",
            "type: заметка",
            "area: личное",
            "project: ",
        ]
        if !tags.isEmpty {
            lines.append("tags:")
            lines += tags.map { "  - \($0)" }
        }
        lines += ["---", "", ""]
        return lines.joined(separator: "\n")
    }
}
