/// Приоритеты плагина Tasks: 🔺 ⏫ 🔼 🔽 ⏬.
public enum TaskPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case lowest = -2, low = -1, none = 0, medium = 1, high = 2, highest = 3

    public var signifier: String? {
        switch self {
        case .highest: "🔺"
        case .high: "⏫"
        case .medium: "🔼"
        case .low: "🔽"
        case .lowest: "⏬"
        case .none: nil
        }
    }

    public init?(signifier: String) {
        guard let match = Self.allCases.first(where: { $0.signifier == signifier }) else { return nil }
        self = match
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct TaskStep: Hashable, Codable, Sendable {
    public var title: String
    public var isDone: Bool

    public init(_ title: String, isDone: Bool = false) {
        self.title = title
        self.isDone = isDone
    }
}

/// Вложенная строка задачи. Порядок сохраняется, чтобы не перемешивать то, что написано руками.
public enum TaskChild: Hashable, Codable, Sendable {
    /// `- [ ] шаг`
    case step(TaskStep)
    /// `- 📍 где остановился`
    case crumb(String)
    /// `- [[файл.pdf]]` — цель ссылки без скобок.
    case attachment(String)
    /// Любая другая строка, хранится как есть вместе с отступом.
    case other(String)
}

public struct AnchorTask: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var isDone: Bool
    public var priority: TaskPriority
    public var due: LocalDate?
    public var doneDate: LocalDate?
    /// Теги без `#`.
    public var tags: [String]
    public var children: [TaskChild]

    public init(
        id: String,
        title: String,
        isDone: Bool = false,
        priority: TaskPriority = .none,
        due: LocalDate? = nil,
        doneDate: LocalDate? = nil,
        tags: [String] = [],
        children: [TaskChild] = []
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.priority = priority
        self.due = due
        self.doneDate = doneDate
        self.tags = tags
        self.children = children
    }

    public var steps: [TaskStep] {
        children.compactMap { if case .step(let step) = $0 { step } else { nil } }
    }

    public var nextStep: TaskStep? { steps.first { !$0.isDone } }

    public var lastCrumb: String? {
        children.lazy.reversed().compactMap { if case .crumb(let text) = $0 { text } else { nil } }.first
    }

    public var attachments: [String] {
        children.compactMap { if case .attachment(let target) = $0 { target } else { nil } }
    }

    public mutating func addStep(_ title: String) {
        children.append(.step(TaskStep(title)))
    }

    public mutating func addCrumb(_ text: String) {
        children.append(.crumb(text))
    }

    public mutating func addAttachment(_ target: String) {
        children.append(.attachment(target))
    }

    /// Переключает шаг с номером `index` среди `steps`.
    public mutating func toggleStep(at index: Int) {
        guard let position = childIndex(ofStep: index), case .step(var step) = children[position] else { return }
        step.isDone.toggle()
        children[position] = .step(step)
    }

    /// Отмечает первый невыполненный шаг. Возвращает `false`, если шагов не осталось.
    @discardableResult
    public mutating func completeNextStep() -> Bool {
        guard let index = steps.firstIndex(where: { !$0.isDone }) else { return false }
        toggleStep(at: index)
        return true
    }

    public mutating func complete(on date: LocalDate) {
        isDone = true
        doneDate = date
    }

    public mutating func reopen() {
        isDone = false
        doneDate = nil
    }

    func childIndex(ofStep index: Int) -> Int? {
        var seen = 0
        for (position, child) in children.enumerated() {
            guard case .step = child else { continue }
            if seen == index { return position }
            seen += 1
        }
        return nil
    }
}

public enum TaskID {
    private static let alphabet = Array("abcdefghijkmnpqrstuvwxyz23456789")

    /// Короткий id для поля `🆔` плагина Tasks.
    public static func make() -> String {
        var rng = SystemRandomNumberGenerator()
        return make(using: &rng)
    }

    public static func make(using rng: inout some RandomNumberGenerator) -> String {
        String((0..<6).map { _ in alphabet.randomElement(using: &rng)! })
    }
}
