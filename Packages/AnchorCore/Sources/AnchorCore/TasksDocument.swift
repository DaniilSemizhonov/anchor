import Foundation

/// Markdown-файл с задачами в формате плагина Tasks.
///
/// Задача — строка `- [ ] …` без отступа и вложенные под ней строки. Всё остальное
/// (заголовки, абзацы, задачи с другими статусами) хранится как есть. Неизменённые задачи
/// выводятся в исходном виде, поэтому правка одной задачи не трогает остальной текст.
public struct TasksDocument: Sendable {
    private enum Segment: Sendable {
        case text(String)
        case task(Block)
    }

    private struct Block: Sendable {
        var task: AnchorTask
        /// Задача сразу после разбора; `nil`, если её надо вывести заново.
        var original: AnchorTask?
        var raw: [String]
        var indent: String
        var idWasGenerated: Bool
    }

    private var segments: [Segment]
    private let endsWithNewline: Bool

    public init(markdown: String, makeID: () -> String = { TaskID.make() }) {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        endsWithNewline = markdown.hasSuffix("\n")
        if endsWithNewline { lines.removeLast() }

        segments = []
        var i = 0
        while i < lines.count {
            guard let head = TaskLine(lines[i]) else {
                segments.append(.text(lines[i]))
                i += 1
                continue
            }
            var childLines: [String] = []
            var j = i + 1
            while j < lines.count, let first = lines[j].first, first == " " || first == "\t" {
                childLines.append(lines[j])
                j += 1
            }
            let indent = childLines.first.map { String($0.prefix { $0 == " " || $0 == "\t" }) } ?? "\t"

            let fields = TaskFields(description: head.description)
            let generated = fields.id == nil
            let task = AnchorTask(
                id: fields.id ?? makeID(),
                title: fields.title,
                isDone: head.isDone,
                priority: fields.priority,
                due: fields.due,
                doneDate: fields.doneDate,
                tags: fields.tags,
                children: childLines.map { Self.parseChild($0, indent: indent) }
            )
            segments.append(.task(Block(
                task: task, original: task, raw: Array(lines[i..<j]), indent: indent, idWasGenerated: generated
            )))
            i = j
        }
    }

    public var tasks: [AnchorTask] {
        segments.compactMap { if case .task(let block) = $0 { block.task } else { nil } }
    }

    public subscript(id id: String) -> AnchorTask? {
        tasks.first { $0.id == id }
    }

    /// Обновляет задачу с тем же id или дописывает новую в конец файла.
    public mutating func upsert(_ task: AnchorTask) {
        if let index = blockIndex(id: task.id), case .task(var block) = segments[index] {
            block.task = task
            segments[index] = .task(block)
        } else {
            segments.append(.task(Block(task: task, original: nil, raw: [], indent: "\t", idWasGenerated: false)))
        }
    }

    public mutating func remove(id: String) {
        if let index = blockIndex(id: id) { segments.remove(at: index) }
    }

    /// Приводит файл к списку задач приложения: изменённые обновляет на месте, новые дописывает
    /// в конец, отсутствующие удаляет. Остальной текст файла и неизменённые задачи не трогает.
    public mutating func sync(with tasks: [AnchorTask]) {
        let keep = Set(tasks.map(\.id))
        segments.removeAll { segment in
            if case .task(let block) = segment { !keep.contains(block.task.id) } else { false }
        }
        for task in tasks { upsert(task) }
    }

    /// Трёхстороннее слияние: в этот документ (версия файла) переносятся только изменения
    /// приложения относительно `base` — того, что было в файле при последней синхронизации.
    /// Задачи, которые добавили или поменяли в Obsidian, а приложение не трогало, остаются.
    public mutating func apply(changesFrom base: [AnchorTask], to ours: [AnchorTask]) {
        let baseByID = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ourIDs = Set(ours.map(\.id))
        for id in baseByID.keys where !ourIDs.contains(id) {
            remove(id: id)
        }
        for task in ours where baseByID[task.id] != task {
            upsert(task)
        }
    }

    /// Задачи, которым id выдан при разборе, а в файле его нет.
    public var hasUnsavedIDs: Bool {
        segments.contains { if case .task(let block) = $0 { block.idWasGenerated } else { false } }
    }

    /// Помечает такие задачи к перезаписи, чтобы `🆔` попал в файл и id не менялся между запусками.
    public mutating func materializeIDs() {
        for index in segments.indices {
            guard case .task(var block) = segments[index], block.idWasGenerated else { continue }
            block.original = nil
            block.idWasGenerated = false
            segments[index] = .task(block)
        }
    }

    public func render() -> String {
        var lines: [String] = []
        for segment in segments {
            switch segment {
            case .text(let line):
                lines.append(line)
            case .task(let block):
                if block.task == block.original {
                    lines.append(contentsOf: block.raw)
                } else {
                    lines.append(contentsOf: Self.render(block.task, indent: block.indent))
                }
            }
        }
        let text = lines.joined(separator: "\n")
        return endsWithNewline || segments.isEmpty ? text + "\n" : text
    }

    private func blockIndex(id: String) -> Int? {
        segments.firstIndex { if case .task(let block) = $0 { block.task.id == id } else { false } }
    }

    // MARK: - Строки

    static func render(_ task: AnchorTask, indent: String) -> [String] {
        var parts = [task.title]
        parts += task.tags.map { "#" + $0 }
        if let signifier = task.priority.signifier { parts.append(signifier) }
        if let due = task.due { parts.append("📅 " + due.iso) }
        if let done = task.doneDate { parts.append("✅ " + done.iso) }
        parts.append("🆔 " + task.id)

        var lines = ["- [\(task.isDone ? "x" : " ")] " + parts.filter { !$0.isEmpty }.joined(separator: " ")]
        for child in task.children {
            switch child {
            case .step(let step): lines.append(indent + "- [\(step.isDone ? "x" : " ")] " + step.title)
            case .crumb(let text): lines.append(indent + "- 📍 " + text)
            case .attachment(let target): lines.append(indent + "- [[" + target + "]]")
            case .other(let raw): lines.append(raw)
            }
        }
        return lines
    }

    private static func parseChild(_ line: String, indent: String) -> TaskChild {
        guard line.hasPrefix(indent) else { return .other(line) }
        let body = line.dropFirst(indent.count)
        guard let first = body.first, first != " ", first != "\t" else { return .other(line) }

        if let step = TaskLine(String(body)) {
            return .step(TaskStep(step.description, isDone: step.isDone))
        }
        if body.hasPrefix("- 📍") {
            return .crumb(body.dropFirst(3).trimmingCharacters(in: .whitespaces))
        }
        for opener in ["- [[", "- ![["] where body.hasPrefix(opener) && body.hasSuffix("]]") {
            let target = body.dropFirst(opener.count).dropLast(2)
            if !target.isEmpty, !target.contains("]") { return .attachment(String(target)) }
        }
        return .other(line)
    }
}

/// `- [ ] описание` / `- [x] описание` без отступа.
struct TaskLine {
    let isDone: Bool
    let description: String

    init?(_ line: String) {
        guard line.hasPrefix("- [") || line.hasPrefix("* [") else { return nil }
        let rest = line.dropFirst(3)
        guard let status = rest.first, rest.dropFirst().hasPrefix("] ") else { return nil }
        switch status {
        case " ": isDone = false
        case "x", "X": isDone = true
        default: return nil
        }
        description = rest.dropFirst(3).trimmingCharacters(in: .whitespaces)
        if description.isEmpty { return nil }
    }
}

/// Поля Tasks внутри описания задачи. Неизвестные поля остаются в названии как есть.
struct TaskFields {
    var title = ""
    var id: String?
    var priority = TaskPriority.none
    var due: LocalDate?
    var doneDate: LocalDate?
    var tags: [String] = []

    private static let dueSignifiers = ["📅", "📆", "🗓"]

    init(description: String) {
        let tokens = description.split(separator: " ").map(String.init)
        var titleTokens: [String] = []
        var i = 0
        while i < tokens.count {
            let token = Self.normalized(tokens[i])
            // Значение поля может идти слитно (`📅2026-10-30`) или следующим словом.
            func value(after signifier: String) -> (String, Int)? {
                guard token.hasPrefix(signifier) else { return nil }
                let rest = String(token.dropFirst(signifier.count))
                if !rest.isEmpty { return (rest, 1) }
                return i + 1 < tokens.count ? (tokens[i + 1], 2) : nil
            }

            if due == nil, let (raw, used) = Self.dueSignifiers.lazy.compactMap({ value(after: $0) }).first,
               let date = LocalDate(iso: raw) {
                due = date
                i += used
            } else if doneDate == nil, let (raw, used) = value(after: "✅"), let date = LocalDate(iso: raw) {
                doneDate = date
                i += used
            } else if id == nil, let (raw, used) = value(after: "🆔"), Self.isID(raw) {
                id = raw
                i += used
            } else if priority == .none, let parsed = TaskPriority(signifier: token) {
                priority = parsed
                i += 1
            } else if let tag = Self.tag(token) {
                tags.append(tag)
                i += 1
            } else {
                titleTokens.append(tokens[i])
                i += 1
            }
        }
        title = titleTokens.joined(separator: " ")
    }

    static func normalized(_ token: String) -> String {
        String(String.UnicodeScalarView(token.unicodeScalars.filter { $0 != "\u{FE0F}" }))
    }

    static func isID(_ raw: String) -> Bool {
        !raw.isEmpty && raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// `#тег`, `#учёба/вышмат`. Числа (`#1`) тегами не считаются — как в Obsidian.
    static func tag(_ token: String) -> String? {
        guard token.hasPrefix("#"), token.count > 1 else { return nil }
        let body = token.dropFirst()
        guard body.allSatisfy({ $0.isLetter || $0.isNumber || "_-/".contains($0) }),
              body.contains(where: { $0.isLetter })
        else { return nil }
        return String(body)
    }
}
