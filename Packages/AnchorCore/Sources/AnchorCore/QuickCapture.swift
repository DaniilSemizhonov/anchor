import Foundation

/// Черновик задачи из строки быстрого ввода.
public struct CaptureDraft: Hashable, Sendable {
    public var title: String
    public var due: LocalDate?
    public var priority: TaskPriority
    public var tags: [String]
    public var steps: [String]

    public func makeTask(id: String) -> AnchorTask? {
        guard !title.isEmpty else { return nil }
        return AnchorTask(
            id: id,
            title: title,
            priority: priority,
            due: due,
            tags: tags,
            children: steps.map { .step(TaskStep($0)) }
        )
    }
}

/// Разбирает быстрый ввод: `прочитать гл. 3 к пт #учёба !`.
///
/// Первая строка — название, слова-даты (`сегодня`, `завтра`, `пт`, `к пятнице`, `30.10`,
/// `через 3 дня`), теги и `!`/`!!`. Следующие строки — шаги, можно с `>` или `-` в начале.
public struct QuickCaptureParser: Sendable {
    public init() {}

    private static let relativeDays = ["сегодня": 0, "завтра": 1, "послезавтра": 2]

    private static let weekdays: [String: Int] = {
        let forms: [[String]] = [
            ["пн", "пон", "понедельник", "понедельнику"],
            ["вт", "вторник", "вторнику"],
            ["ср", "среда", "среду", "среде"],
            ["чт", "четверг", "четвергу"],
            ["пт", "пятница", "пятницу", "пятнице"],
            ["сб", "суббота", "субботу", "субботе"],
            ["вс", "воскресенье", "воскресенью"],
        ]
        var map: [String: Int] = [:]
        for (index, names) in forms.enumerated() {
            for name in names { map[name] = index + 1 }
        }
        return map
    }()

    /// Предлоги, которые съедаются вместе с датой: «в пт», «к пятнице», «до 30.10».
    private static let datePrepositions: Set<String> = ["в", "во", "к", "ко", "до"]

    public func parse(_ input: String, today: LocalDate) -> CaptureDraft {
        let lines = input.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        let tokens = (lines.first ?? "").split(whereSeparator: \.isWhitespace).map(String.init)

        var draft = CaptureDraft(title: "", due: nil, priority: .none, tags: [], steps: [])
        var titleTokens: [String] = []
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            let word = Self.keyword(token)

            if draft.due == nil, let (date, used) = date(at: i, in: tokens, today: today) {
                draft.due = date
                i += used
            } else if draft.due == nil, Self.datePrepositions.contains(word), i + 1 < tokens.count,
                      let (date, used) = date(at: i + 1, in: tokens, today: today) {
                draft.due = date
                i += used + 1
            } else if token == "!" || token == "!!" {
                draft.priority = token == "!" ? .high : .highest
                i += 1
            } else if let tag = TaskFields.tag(token) {
                draft.tags.append(tag)
                i += 1
            } else {
                titleTokens.append(token)
                i += 1
            }
        }
        draft.title = titleTokens.joined(separator: " ")

        for line in lines.dropFirst() {
            var step = line.trimmingCharacters(in: .whitespaces)
            if let first = step.first, ">-•".contains(first) {
                step = step.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            if !step.isEmpty { draft.steps.append(step) }
        }
        return draft
    }

    /// Дата, начинающаяся с `tokens[index]`, и сколько слов она заняла.
    private func date(at index: Int, in tokens: [String], today: LocalDate) -> (LocalDate, Int)? {
        let word = Self.keyword(tokens[index])

        if let offset = Self.relativeDays[word] {
            return (today.adding(days: offset), 1)
        }
        if let weekday = Self.weekdays[word] {
            // Тот же день недели — значит следующая неделя.
            let delta = (weekday - today.weekday + 7) % 7
            return (today.adding(days: delta == 0 ? 7 : delta), 1)
        }
        if word == "через", index + 1 < tokens.count {
            return relative(after: index, in: tokens, today: today)
        }
        if let date = Self.numericDate(word, today: today) {
            return (date, 1)
        }
        return nil
    }

    /// «через 3 дня», «через 3д», «через неделю», «через 2 недели».
    private func relative(after index: Int, in tokens: [String], today: LocalDate) -> (LocalDate, Int)? {
        let next = Self.keyword(tokens[index + 1])
        if next == "день" { return (today.adding(days: 1), 2) }
        if next == "неделю" { return (today.adding(days: 7), 2) }

        let digits = next.prefix { $0.isNumber }
        guard let count = Int(digits), count > 0 else { return nil }
        var unit = String(next.dropFirst(digits.count))
        var used = 2
        if unit.isEmpty, index + 2 < tokens.count {
            unit = Self.keyword(tokens[index + 2])
            used = 3
        }
        if unit.hasPrefix("д") { return (today.adding(days: count), used) }
        if unit.hasPrefix("нед") { return (today.adding(days: count * 7), used) }
        return nil
    }

    /// `30.10`, `30/10`, `30.10.2026`, `30.10.26`. Без года — ближайшая будущая такая дата.
    static func numericDate(_ word: String, today: LocalDate) -> LocalDate? {
        let parts = word.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "." || $0 == "/" })
        guard parts.count == 2 || parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.count <= 4 && $0.allSatisfy { $0.isNumber } }),
              let day = Int(parts[0]), let month = Int(parts[1]),
              parts[0].count <= 2, parts[1].count <= 2
        else { return nil }

        if parts.count == 3, let rawYear = Int(parts[2]) {
            let year = parts[2].count == 2 ? 2000 + rawYear : rawYear
            return parts[2].count == 2 || parts[2].count == 4 ? LocalDate(year: year, month: month, day: day) : nil
        }
        guard let thisYear = LocalDate(year: today.year, month: month, day: day) else {
            return LocalDate(year: today.year + 1, month: month, day: day)
        }
        return thisYear < today ? LocalDate(year: today.year + 1, month: month, day: day) : thisYear
    }

    private static func keyword(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ",;:"))
            .replacingOccurrences(of: "ё", with: "е")
    }
}
