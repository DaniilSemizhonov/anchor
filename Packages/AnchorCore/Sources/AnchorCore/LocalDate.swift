import Foundation

/// Календарная дата без времени и часового пояса — как поля Tasks (`📅 2026-10-30`).
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= LocalDate.daysIn(month: month, year: year) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Разбирает `YYYY-MM-DD`.
    public init?(iso: some StringProtocol) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(unchecked: c.year!, c.month!, c.day!)
    }

    private init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public var description: String { iso }

    public func adding(days: Int) -> LocalDate { LocalDate(dayNumber: dayNumber + days) }

    /// Сколько дней от `self` до `other` (отрицательно, если `other` раньше).
    public func days(until other: LocalDate) -> Int { other.dayNumber - dayNumber }

    /// 1 — понедельник … 7 — воскресенье.
    public var weekday: Int { ((dayNumber % 7 + 7) % 7 + 3) % 7 + 1 }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool { lhs.dayNumber < rhs.dayNumber }

    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    // Дни от 1970-01-01, алгоритмы days_from_civil / civil_from_days (Howard Hinnant).
    var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(unchecked: yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

extension LocalDate: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let date = LocalDate(iso: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Не дата: \(raw)"))
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}

extension LocalDate {
    private static let monthsShort = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    private static let weekdaysShort = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

    /// Подпись срока для интерфейса: «сегодня», «завтра», «пт», «30 окт», «вчера».
    public func shortLabel(relativeTo today: LocalDate) -> String {
        switch today.days(until: self) {
        case 0: "сегодня"
        case 1: "завтра"
        case -1: "вчера"
        case 2...6: Self.weekdaysShort[weekday - 1]
        default:
            year == today.year
                ? "\(day) \(Self.monthsShort[month - 1])"
                : "\(day) \(Self.monthsShort[month - 1]) \(year)"
        }
    }
}
