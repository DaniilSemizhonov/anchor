import Foundation
import Testing
@testable import AnchorCore

@Suite struct TasksDocumentTests {
    private let sample = """
    ---
    title: Задачи
    ---

    # Сегодня

    - [ ] Дописать доклад #учёба ⏫ 📅 2026-10-30 🆔 a7k2
    \t- [x] Введение
    \t- [ ] Выводы
    \t- 📍 остановился на графиках
    \t- [[Глава 3.pdf]]
    \t\t- вложенная мысль
    - [x] Купить батарейки ✅ 2026-10-28 🆔 b3m9
    - [/] В процессе, не трогаем
    Просто абзац с - [ ] внутри

    """

    @Test func parsesTasksAndFields() throws {
        let doc = TasksDocument(markdown: sample)
        #expect(doc.tasks.count == 2)

        let talk = try #require(doc[id: "a7k2"])
        #expect(talk.title == "Дописать доклад")
        #expect(talk.tags == ["учёба"])
        #expect(talk.priority == .high)
        #expect(talk.due == LocalDate(iso: "2026-10-30"))
        #expect(!talk.isDone)
        #expect(talk.steps == [TaskStep("Введение", isDone: true), TaskStep("Выводы")])
        #expect(talk.nextStep?.title == "Выводы")
        #expect(talk.lastCrumb == "остановился на графиках")
        #expect(talk.attachments == ["Глава 3.pdf"])
        #expect(talk.children.last == .other("\t\t- вложенная мысль"))

        let batteries = try #require(doc[id: "b3m9"])
        #expect(batteries.isDone)
        #expect(batteries.doneDate == LocalDate(iso: "2026-10-28"))
    }

    @Test func untouchedDocumentRoundTripsExactly() {
        #expect(TasksDocument(markdown: sample).render() == sample)
        #expect(TasksDocument(markdown: "без переноса в конце").render() == "без переноса в конце")
    }

    @Test func editingOneTaskKeepsTheRest() throws {
        var doc = TasksDocument(markdown: sample)
        var talk = try #require(doc[id: "a7k2"])
        talk.completeNextStep()
        talk.addCrumb("осталось оформить")
        doc.upsert(talk)

        let expected = sample.replacingOccurrences(
            of: "\t- [ ] Выводы", with: "\t- [x] Выводы"
        ).replacingOccurrences(
            of: "\t\t- вложенная мысль\n", with: "\t\t- вложенная мысль\n\t- 📍 осталось оформить\n"
        ).replacingOccurrences(
            of: "#учёба ⏫ 📅 2026-10-30 🆔 a7k2", with: "#учёба ⏫ 📅 2026-10-30 🆔 a7k2"
        )
        #expect(doc.render() == expected)
    }

    @Test func appendsNewTaskAtEnd() {
        var doc = TasksDocument(markdown: "# Задачи\n")
        doc.upsert(AnchorTask(
            id: "zz11", title: "Позвонить", priority: .highest, due: LocalDate(iso: "2026-11-02"),
            tags: ["работа"], children: [.step(TaskStep("Найти номер"))]
        ))
        #expect(doc.render() == "# Задачи\n- [ ] Позвонить #работа 🔺 📅 2026-11-02 🆔 zz11\n\t- [ ] Найти номер\n")
    }

    @Test func removesTaskWithChildren() {
        var doc = TasksDocument(markdown: sample)
        doc.remove(id: "a7k2")
        #expect(doc.tasks.map(\.id) == ["b3m9"])
        #expect(!doc.render().contains("Введение"))
    }

    @Test func handWrittenTaskGetsIDOnlyWhenMaterialized() {
        var doc = TasksDocument(markdown: "- [ ] Без id 📅 2026-11-01\n", makeID: { "new1" })
        #expect(doc.tasks.first?.id == "new1")
        #expect(doc.hasUnsavedIDs)
        #expect(doc.render() == "- [ ] Без id 📅 2026-11-01\n")
        doc.materializeIDs()
        #expect(!doc.hasUnsavedIDs)
        #expect(doc.render() == "- [ ] Без id 📅 2026-11-01 🆔 new1\n")
    }

    @Test func fieldVariants() {
        let fields = TaskFields(description: "Задача 📅2026-11-01 🔁 every week #1 #a/b ⏬")
        #expect(fields.due == LocalDate(iso: "2026-11-01"))
        #expect(fields.priority == .lowest)
        #expect(fields.tags == ["a/b"])
        #expect(fields.title == "Задача 🔁 every week #1")
    }

    @Test func spacesIndentIsKept() throws {
        var doc = TasksDocument(markdown: "- [ ] A 🆔 x1\n    - [ ] шаг\n")
        var task = try #require(doc[id: "x1"])
        task.addStep("ещё")
        doc.upsert(task)
        #expect(doc.render() == "- [ ] A 🆔 x1\n    - [ ] шаг\n    - [ ] ещё\n")
    }
}
