import Testing
@testable import AnchorCore

@Suite struct QuickCaptureTests {
    /// Четверг.
    private let today = LocalDate(iso: "2026-10-29")!
    private let parser = QuickCaptureParser()

    private func due(_ input: String) -> String? { parser.parse(input, today: today).due?.iso }

    @Test func plainTitle() {
        let draft = parser.parse("Купить батарейки", today: today)
        #expect(draft.title == "Купить батарейки")
        #expect(draft.due == nil)
        #expect(draft.priority == .none)
    }

    @Test func fullLine() {
        let draft = parser.parse("прочитать гл. 3 к пятнице #учёба/вышмат !", today: today)
        #expect(draft.title == "прочитать гл. 3")
        #expect(draft.due?.iso == "2026-10-30")
        #expect(draft.tags == ["учёба/вышмат"])
        #expect(draft.priority == .high)
    }

    @Test func relativeWords() {
        #expect(due("x сегодня") == "2026-10-29")
        #expect(due("x Завтра") == "2026-10-30")
        #expect(due("x послезавтра") == "2026-10-31")
        #expect(due("x через 3 дня") == "2026-11-01")
        #expect(due("x через 3д") == "2026-11-01")
        #expect(due("x через день") == "2026-10-30")
        #expect(due("x через неделю") == "2026-11-05")
        #expect(due("x через 2 недели") == "2026-11-12")
    }

    @Test func weekdays() {
        #expect(due("x пн") == "2026-11-02")
        #expect(due("x в среду") == "2026-11-04")
        #expect(due("x во вторник") == "2026-11-03")
        #expect(due("x до воскресенья") == nil) // родительный падеж пока не понимаем
        #expect(due("x чт") == "2026-11-05") // тот же день недели → следующая неделя
    }

    @Test func numericDates() {
        #expect(due("x 30.10") == "2026-10-30")
        #expect(due("x 01.10") == "2027-10-01") // уже прошло → следующий год
        #expect(due("x 5/11") == "2026-11-05")
        #expect(due("x 30.10.2027") == "2027-10-30")
        #expect(due("x 30.10.27") == "2027-10-30")
        #expect(due("x 31.02") == nil)
        #expect(due("глава 3") == nil)
    }

    @Test func prepositionStaysWhenNotDate() {
        let draft = parser.parse("сходить в магазин завтра", today: today)
        #expect(draft.title == "сходить в магазин")
        #expect(draft.due?.iso == "2026-10-30")
    }

    @Test func onlyFirstDateCounts() {
        let draft = parser.parse("перенести с пт на пн", today: today)
        #expect(draft.due?.iso == "2026-10-30")
        #expect(draft.title == "перенести с на пн")
    }

    @Test func stepsFromNextLines() throws {
        let draft = parser.parse("Доклад !!\n> план\n- слайды\n\n  репетиция", today: today)
        #expect(draft.priority == .highest)
        #expect(draft.steps == ["план", "слайды", "репетиция"])
        let task = try #require(draft.makeTask(id: "t1"))
        #expect(task.nextStep?.title == "план")
    }

    @Test func emptyTitleMakesNoTask() {
        #expect(parser.parse("завтра #дом", today: today).makeTask(id: "t") == nil)
    }
}
