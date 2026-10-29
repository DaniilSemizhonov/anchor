import AnchorCore
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var tasks: [AnchorTask] = []
    private(set) var currentTaskID: String?
    private(set) var session = FocusSession()
    /// Развёрнута по клику, а не только по наведению.
    var isPinnedExpanded = false
    /// Курсор над карточкой (с задержкой, см. PanelController).
    var isHovering = false

    @ObservationIgnored private let store: LocalStore?
    @ObservationIgnored private let parser = QuickCaptureParser()

    init(store: LocalStore?) {
        self.store = store
        if let snapshot = store?.load() {
            tasks = snapshot.tasks
            currentTaskID = snapshot.currentTaskID
            session = snapshot.session
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

    /// Что дальше: важное и срочное сверху, без сроков — в конце.
    var upcoming: [AnchorTask] {
        let open = tasks.filter { !$0.isDone && $0.id != currentTaskID }
        let sorted = open.sorted { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            switch (a.due, b.due) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            default: return false
            }
        }
        return Array(sorted.prefix(5))
    }

    // MARK: - Действия

    func capture(_ text: String, makeCurrent: Bool = false) {
        guard let task = parser.parse(text, today: today).makeTask(id: TaskID.make()) else { return }
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

    func toggleStep(at index: Int) {
        updateCurrent { $0.toggleStep(at: index) }
    }

    func completeNextStep() {
        updateCurrent { $0.completeNextStep() }
    }

    func completeCurrentTask() {
        let date = today
        updateCurrent { $0.complete(on: date) }
        if let next = upcoming.first {
            focus(on: next.id)
        } else {
            currentTaskID = nil
            session.stop()
            save()
        }
    }

    func togglePause() {
        if session.isRunning {
            session.pause(at: .now)
        } else {
            session.resume(at: .now)
        }
        save()
    }

    private func updateCurrent(_ change: (inout AnchorTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == currentTaskID }) else { return }
        change(&tasks[index])
        save()
    }

    private func save() {
        store?.save(.init(tasks: tasks, currentTaskID: currentTaskID, session: session))
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
        ]
        currentTaskID = report.id
        session.focus(on: report.id, at: Date(timeIntervalSinceNow: -23 * 60))
    }
}
