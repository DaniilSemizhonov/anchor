import Foundation
import Testing
@testable import AnchorCore

@Suite struct FocusSessionTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsWithPauses() {
        var session = FocusSession()
        session.focus(on: "a", at: t0)
        #expect(session.elapsed(at: t0 + 600) == 600)
        session.pause(at: t0 + 600)
        #expect(!session.isRunning)
        #expect(session.elapsed(at: t0 + 5000) == 600)
        session.resume(at: t0 + 5000)
        #expect(session.elapsed(at: t0 + 5060) == 660)
    }

    @Test func switchingTaskResets() {
        var session = FocusSession()
        session.focus(on: "a", at: t0)
        session.focus(on: "a", at: t0 + 100)
        #expect(session.elapsed(at: t0 + 200) == 200)
        session.focus(on: "b", at: t0 + 200)
        #expect(session.taskID == "b")
        #expect(session.elapsed(at: t0 + 230) == 30)
    }

    @Test func clockFormat() {
        #expect(FocusClock.format(20) == "<1 мин")
        #expect(FocusClock.format(23 * 60 + 59) == "23 мин")
        #expect(FocusClock.format(65 * 60) == "1 ч 05 мин")
    }
}
