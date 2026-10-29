import Testing
@testable import AnchorCore

@Suite struct TaskQueueTests {
    private let today = LocalDate(iso: "2026-10-29")! // четверг

    private func task(_ id: String, _ priority: TaskPriority = .none, due: String? = nil, done: Bool = false) -> AnchorTask {
        AnchorTask(id: id, title: id, isDone: done, priority: priority, due: due.flatMap { LocalDate(iso: $0) })
    }

    @Test func ordersByPriorityThenDueThenOriginal() {
        let tasks = [
            task("a"),
            task("b", due: "2026-11-05"),
            task("c", .high),
            task("d", due: "2026-10-28"),
            task("e", done: true),
            task("f"),
            task("g", due: "2026-10-28"),
        ]
        #expect(TaskQueue.ordered(tasks).map(\.id) == ["c", "d", "g", "b", "a", "f"])
    }

    @Test func neighbors() {
        let tasks = [task("a"), task("b"), task("c")]
        #expect(TaskQueue.neighbor(of: "b", in: tasks, offset: 1) == "c")
        #expect(TaskQueue.neighbor(of: "b", in: tasks, offset: -1) == "a")
        #expect(TaskQueue.neighbor(of: "c", in: tasks, offset: 1) == nil)
        #expect(TaskQueue.neighbor(of: "a", in: tasks, offset: -1) == nil)
        #expect(TaskQueue.neighbor(of: nil, in: tasks, offset: 1) == "a")
        #expect(TaskQueue.neighbor(of: "x", in: [], offset: 1) == nil)
    }

    @Test func postpone() {
        #expect(PostponeOption.tomorrow.due(from: today)?.iso == "2026-10-30")
        #expect(PostponeOption.nextWeek.due(from: today)?.iso == "2026-11-02")
        #expect(PostponeOption.nextWeek.due(from: LocalDate(iso: "2026-11-02")!)?.iso == "2026-11-09")
        #expect(PostponeOption.nextWeek.due(from: LocalDate(iso: "2026-11-01")!)?.iso == "2026-11-02")
        #expect(PostponeOption.noDate.due(from: today) == nil)
    }

    @Test func stepEditing() {
        var t = AnchorTask(id: "t", title: "t", children: [.step(TaskStep("a")), .crumb("c"), .step(TaskStep("b"))])
        t.renameStep(at: 1, to: "B")
        #expect(t.steps.map(\.title) == ["a", "B"])
        t.removeStep(at: 0)
        #expect(t.children == [.crumb("c"), .step(TaskStep("B"))])
        t.removeStep(at: 5)
        #expect(t.steps.count == 1)
    }
}
