import Testing
@testable import AnchorCore

@Suite struct VaultDocumentsTests {
    private let file = """
    ---
    title: Задачи Anchor
    ---

    Мои заметки сверху.

    - [ ] Первая 🆔 a1
    - [x] Сделанная ✅ 2026-10-29 🆔 a2
    - [/] Чужой статус
    - [ ] Удалить меня 🆔 a3

    """

    @Test func syncUpdatesAddsRemovesAndKeepsText() throws {
        var doc = TasksDocument(markdown: file)
        var first = try #require(doc[id: "a1"])
        first.addStep("шаг")
        let done = try #require(doc[id: "a2"])
        let added = AnchorTask(id: "n1", title: "Новая")
        doc.sync(with: [first, done, added])

        #expect(doc.render() == """
        ---
        title: Задачи Anchor
        ---

        Мои заметки сверху.

        - [ ] Первая 🆔 a1
        \t- [ ] шаг
        - [x] Сделанная ✅ 2026-10-29 🆔 a2
        - [/] Чужой статус
        - [ ] Новая 🆔 n1

        """)
    }

    @Test func syncWithSameTasksChangesNothing() {
        var doc = TasksDocument(markdown: file)
        doc.sync(with: doc.tasks)
        #expect(doc.render() == file)
    }

    private let parking = """
    ---
    title: Парковка
    ---

    - Посмотреть курс
    - [ ] это задача, не трогаем
    - Подарок маме

    Хвост.

    """

    @Test func parkingParsesItems() {
        #expect(ParkingDocument(markdown: parking).items == ["Посмотреть курс", "Подарок маме"])
        #expect(ParkingDocument(markdown: parking).render() == parking)
    }

    @Test func parkingSyncReplacesItemsInPlace() {
        var doc = ParkingDocument(markdown: parking)
        doc.sync(with: ["Подарок маме", "Новая\nмысль"])
        #expect(doc.render() == """
        ---
        title: Парковка
        ---

        - Подарок маме
        - Новая мысль
        - [ ] это задача, не трогаем

        Хвост.

        """)
    }

    @Test func parkingSyncIntoFileWithoutItems() {
        var doc = ParkingDocument(markdown: "# Парковка\n")
        doc.sync(with: ["мысль"])
        #expect(doc.render() == "# Парковка\n- мысль\n")
        doc.sync(with: [])
        #expect(doc.render() == "# Парковка\n")
    }

    @Test func mergeKeepsTheirChangesAndAppliesOurs() throws {
        let base = TasksDocument(markdown: "- [ ] A 🆔 a\n- [ ] B 🆔 b\n- [ ] C 🆔 c\n").tasks
        // В Obsidian: A переименовали, добавили D.
        var theirs = TasksDocument(markdown: "- [ ] A2 🆔 a\n- [ ] B 🆔 b\n- [ ] C 🆔 c\n- [ ] D 🆔 d\n")
        // В приложении: B выполнена, C удалена, добавлена E.
        var ours = base
        ours[1].complete(on: LocalDate(iso: "2026-10-30")!)
        ours.remove(at: 2)
        ours.append(AnchorTask(id: "e", title: "E"))

        theirs.apply(changesFrom: base, to: ours)
        #expect(theirs.render() == "- [ ] A2 🆔 a\n- [x] B ✅ 2026-10-30 🆔 b\n- [ ] D 🆔 d\n- [ ] E 🆔 e\n")
    }
}
