import Foundation
import Testing
@testable import AnchorCore

@Suite struct LocalDateTests {
    @Test func parsesAndPrintsISO() throws {
        let date = try #require(LocalDate(iso: "2026-10-29"))
        #expect(date.iso == "2026-10-29")
        #expect(LocalDate(iso: "2026-02-30") == nil)
        #expect(LocalDate(iso: "2026-1-05") == nil)
        #expect(LocalDate(iso: "завтра") == nil)
    }

    @Test func weekdayAndArithmetic() throws {
        let thursday = try #require(LocalDate(iso: "2026-10-29"))
        #expect(thursday.weekday == 4)
        #expect(thursday.adding(days: 3).iso == "2026-11-01")
        #expect(thursday.adding(days: 3).weekday == 7)
        #expect(try #require(LocalDate(iso: "2028-02-28")).adding(days: 1).iso == "2028-02-29")
        #expect(try #require(LocalDate(iso: "2026-12-31")).adding(days: 1).iso == "2027-01-01")
        #expect(try #require(LocalDate(iso: "1970-01-01")).weekday == 4)
        #expect(try #require(LocalDate(iso: "1969-12-29")).weekday == 1)
    }

    @Test func shortLabels() throws {
        let today = try #require(LocalDate(iso: "2026-10-29"))
        #expect(today.shortLabel(relativeTo: today) == "сегодня")
        #expect(today.adding(days: 1).shortLabel(relativeTo: today) == "завтра")
        #expect(today.adding(days: -1).shortLabel(relativeTo: today) == "вчера")
        #expect(today.adding(days: 2).shortLabel(relativeTo: today) == "сб")
        #expect(today.adding(days: 10).shortLabel(relativeTo: today) == "8 ноя")
        #expect(today.adding(days: 70).shortLabel(relativeTo: today) == "7 янв 2027")
    }

    @Test func codableAsString() throws {
        let date = try #require(LocalDate(iso: "2026-10-29"))
        let data = try JSONEncoder().encode([date])
        #expect(String(decoding: data, as: UTF8.self) == #"["2026-10-29"]"#)
        #expect(try JSONDecoder().decode([LocalDate].self, from: data) == [date])
    }
}
