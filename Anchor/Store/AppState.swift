import AnchorCore
import Foundation
import Observation

/// Строка, которую можно свайпать и редактировать.
enum RowID: Hashable {
    case pill
    case step(Int)
    case task(String)
    case parked(String)
}

/// Мысль в парковке: всплыла во время работы, но задачей пока не стала.
struct ParkedThought: Identifiable, Codable, Hashable {
    let id: String
    var text: String
    let created: Date
}

@MainActor
@Observable
final class AppState {
    private(set) var tasks: [AnchorTask] = []
    private(set) var currentTaskID: String?
    private(set) var session = FocusSession()
    private(set) var parked: [ParkedThought] = []
    /// Развёрнута по клику, а не только по наведению.
    var isPinnedExpanded = false
    /// Курсор над карточкой (с задержкой, см. PanelController).
    var isHovering = false
    /// Какая строка сейчас переименовывается.
    var editing: RowID?
    /// Последнее действие, которое можно отменить.
    private(set) var undo: UndoEntry?

    struct UndoEntry {
        let message: String
        fileprivate let tasks: [AnchorTask]
        fileprivate let currentTaskID: String?
        fileprivate let session: FocusSession
        fileprivate let parked: [ParkedThought]
    }

    @ObservationIgnored private let store: LocalStore?
    @ObservationIgnored private let parser = QuickCaptureParser()
    @ObservationIgnored private var undoExpiry: Task<Void, Never>?
    /// Синхронизация с Obsidian; `nil` в демо-режиме.
    @ObservationIgnored var vault: VaultSync?

    init(store: LocalStore?) {
        self.store = store
        if let snapshot = store?.load() {
            tasks = snapshot.tasks
            currentTaskID = snapshot.currentTaskID
            session = snapshot.session
            parked = snapshot.parked ?? []
        }
    }

    /// `--demo` — выдуманные задачи без сохранения (для скриншотов в CI), `--expanded` — сразу развёрнута.
    static func makeDefault() -> AppState {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--demo") else { return AppState(store: LocalStore()) }
        let state = AppState(store: nil)
        state.loadDemo()
        state.isPinnedExpanded = arguments.contains("--expanded")
        return state
    }

    var today: LocalDate { LocalDate(Date()) }

    var currentTask: AnchorTask? {
        tasks.first { $0.id == currentTaskID }
    }

    /// Что дальше, без текущей задачи.
    var upcoming: [AnchorTask] {
        TaskQueue.ordered(tasks).filter { $0.id != currentTaskID }
    }

    var doneTodayCount: Int {
        tasks.count { $0.isDone && $0.doneDate == today }
    }

    func task(_ id: String) -> AnchorTask? {
        tasks.first { $0.id == id }
    }

    // MARK: - Задачи

    func capture(_ text: String, makeCurrent: Bool = false) {
        guard let task = parser.parse(text, today: today).makeTask(id: TaskID.make()) else { return }
        recordUndo("Добавлено: \(task.title)")
        tasks.append(task)
        if makeCurrent || currentTaskID == nil {
            focus(on: task.id)
        } else {
            save()
        }
    }

    func focus(on id: String) {
        currentTaskID = id
        session.focus(on: id, at: .now)
        save()
    }

    /// Переключиться на соседнюю задачу (скролл по таблетке). Возвращает `false`, если дальше некуда.
    @discardableResult
    func switchTask(by offset: Int) -> Bool {
        guard let id = TaskQueue.neighbor(of: currentTaskID, in: tasks, offset: offset) else { return false }
        focus(on: id)
        return true
    }

    func complete(_ id: String) {
        guard let title = task(id)?.title else { return }
        recordUndo("Готово: \(title)")
        let date = today
        update(id) { $0.complete(on: date) }
        if id == currentTaskID { focusNext() }
    }

    func postpone(_ id: String, _ option: PostponeOption) {
        guard let title = task(id)?.title else { return }
        recordUndo("Отложено: \(title)")
        let due = option.due(from: today)
        update(id) { $0.due = due }
        if id == currentTaskID { focusNext(excluding: id) }
    }

    func delete(_ id: String) {
        guard let title = task(id)?.title else { return }
        recordUndo("Удалено: \(title)")
        tasks.removeAll { $0.id == id }
        if id == currentTaskID { focusNext() } else { save() }
    }

    func rename(_ id: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.title = trimmed }
    }

    // MARK: - Парковка

    func park(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recordUndo("В парковке: \(trimmed)")
        parked.append(ParkedThought(id: TaskID.make(), text: trimmed, created: .now))
        save()
    }

    /// Мысль становится задачей (с разбором дат и тегов, как в быстром вводе).
    func promoteParked(_ id: String) {
        guard let thought = parked.first(where: { $0.id == id }),
              let task = parser.parse(thought.text, today: today).makeTask(id: TaskID.make())
        else { return }
        recordUndo("В задачи: \(task.title)")
        parked.removeAll { $0.id == id }
        tasks.append(task)
        if currentTaskID == nil { focus(on: task.id) } else { save() }
    }

    func deleteParked(_ id: String) {
        guard let thought = parked.first(where: { $0.id == id }) else { return }
        recordUndo("Удалено из парковки: \(thought.text)")
        parked.removeAll { $0.id == id }
        save()
    }

    // MARK: - Шаги текущей задачи

    /// «Где остановился» у текущей задачи.
    func addCrumb(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, currentTaskID != nil else { return }
        recordUndo("📍 \(trimmed)")
        updateCurrent { $0.addCrumb(trimmed) }
    }

    func toggleStep(at index: Int) {
        updateCurrent { $0.toggleStep(at: index) }
    }

    /// Свайп по таблетке: следующий шаг, а если шагов не осталось — вся задача.
    func completeNextStepOrTask() {
        guard let task = currentTask else { return }
        if let step = task.nextStep {
            recordUndo("Шаг готов: \(step.title)")
            updateCurrent { $0.completeNextStep() }
        } else {
            complete(task.id)
        }
    }

    func addStep(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        updateCurrent { $0.addStep(trimmed) }
    }

    func renameStep(at index: Int, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        updateCurrent { $0.renameStep(at: index, to: trimmed) }
    }

    func removeStep(at index: Int) {
        guard let step = currentTask?.steps[safe: index] else { return }
        recordUndo("Шаг удалён: \(step.title)")
        updateCurrent { $0.removeStep(at: index) }
    }

    // MARK: - Таймер

    func togglePause() {
        if session.isRunning {
            session.pause(at: .now)
        } else {
            session.resume(at: .now)
        }
        save()
    }

    // MARK: - Отмена

    func performUndo() {
        guard let entry = undo else { return }
        tasks = entry.tasks
        currentTaskID = entry.currentTaskID
        session = entry.session
        parked = entry.parked
        clearUndo()
        save()
    }

    func clearUndo() {
        undoExpiry?.cancel()
        undo = nil
    }

    private func recordUndo(_ message: String) {
        undo = UndoEntry(message: message, tasks: tasks, currentTaskID: currentTaskID, session: session, parked: parked)
        undoExpiry?.cancel()
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.undo = nil
        }
    }

    // MARK: - Служебное

    private func focusNext(excluding id: String? = nil) {
        if let next = upcoming.first(where: { $0.id != id }) {
            focus(on: next.id)
        } else {
            currentTaskID = nil
            session.stop()
            save()
        }
    }

    private func update(_ id: String, _ change: (inout AnchorTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
        save()
    }

    private func updateCurrent(_ change: (inout AnchorTask) -> Void) {
        guard let id = currentTaskID else { return }
        update(id, change)
    }

    private func save() {
        saveLocally()
        vault?.write(tasks: tasks, parked: parked.map(\.text))
    }

    private func saveLocally() {
        store?.save(.init(tasks: tasks, currentTaskID: currentTaskID, session: session, parked: parked))
    }

    /// Данные из хранилища Obsidian (файл поменяли там или слили с нашими правками).
    /// Обратно в хранилище не пишет — иначе запись зациклится.
    func replaceFromVault(tasks newTasks: [AnchorTask], parked texts: [String]) {
        tasks = newTasks
        // Мысли с тем же текстом сохраняют id, чтобы строки в списке не прыгали.
        var pool = parked
        parked = texts.map { text in
            if let index = pool.firstIndex(where: { $0.text == text }) {
                return pool.remove(at: index)
            }
            return ParkedThought(id: TaskID.make(), text: text, created: .now)
        }
        if let id = currentTaskID, task(id).map({ $0.isDone }) ?? true {
            if let next = upcoming.first {
                currentTaskID = next.id
                session.focus(on: next.id, at: .now)
            } else {
                currentTaskID = nil
                session.stop()
            }
        }
        saveLocally()
    }

    private func loadDemo() {
        let parse = { (text: String) in self.parser.parse(text, today: self.today).makeTask(id: TaskID.make())! }
        var report = parse("Дописать доклад по истории завтра #учёба !\n> введение\n> основная часть\n> выводы")
        report.toggleStep(at: 0)
        report.addCrumb("остановился на второй главе")
        tasks = [
            report,
            parse("Разобрать почту сегодня"),
            parse("Купить батарейки #дом"),
            parse("Записаться к врачу пт"),
            parse("Позвонить бабушке"),
            parse("Прочитать главу 3 через неделю"),
            parse("Оплатить интернет 05.11"),
        ]
        var done = parse("Выпить воды")
        done.complete(on: today)
        tasks.append(done)
        parked = [
            ParkedThought(id: "p1", text: "Посмотреть курс по SwiftUI", created: .now),
            ParkedThought(id: "p2", text: "Подарок маме на ДР", created: .now),
        ]
        currentTaskID = report.id
        session.focus(on: report.id, at: Date(timeIntervalSinceNow: -23 * 60))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
