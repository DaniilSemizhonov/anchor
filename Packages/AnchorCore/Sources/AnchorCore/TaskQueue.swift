/// Порядок задач «что дальше» и переключение между ними.
public enum TaskQueue {
    /// Открытые задачи: важные выше, затем по сроку (просроченные и ближние раньше), без срока — в конце.
    /// При равенстве сохраняется исходный порядок, чтобы список не прыгал.
    public static func ordered(_ tasks: [AnchorTask]) -> [AnchorTask] {
        tasks.enumerated()
            .filter { !$0.element.isDone }
            .sorted { lhs, rhs in
                let a = lhs.element, b = rhs.element
                if a.priority != b.priority { return a.priority > b.priority }
                switch (a.due, b.due) {
                case let (x?, y?) where x != y: return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                default: return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    /// Задача на `offset` позиций от текущей в общем порядке; `nil`, если дальше некуда.
    public static func neighbor(of currentID: String?, in tasks: [AnchorTask], offset: Int) -> String? {
        let queue = ordered(tasks)
        guard !queue.isEmpty else { return nil }
        guard let index = queue.firstIndex(where: { $0.id == currentID }) else {
            return queue.first?.id
        }
        let target = index + offset
        return queue.indices.contains(target) && target != index ? queue[target].id : nil
    }
}

/// Варианты «отложить».
public enum PostponeOption: CaseIterable, Sendable {
    case tomorrow
    case nextWeek
    case noDate

    public var title: String {
        switch self {
        case .tomorrow: "На завтра"
        case .nextWeek: "На следующую неделю"
        case .noDate: "Без срока"
        }
    }

    /// Новый срок; для «следующей недели» — ближайший понедельник после сегодняшнего.
    public func due(from today: LocalDate) -> LocalDate? {
        switch self {
        case .tomorrow: today.adding(days: 1)
        case .nextWeek: today.adding(days: 8 - today.weekday)
        case .noDate: nil
        }
    }
}

extension AnchorTask {
    public mutating func renameStep(at index: Int, to title: String) {
        guard let position = childIndex(ofStep: index), case .step(var step) = children[position] else { return }
        step.title = title
        children[position] = .step(step)
    }

    public mutating func removeStep(at index: Int) {
        guard let position = childIndex(ofStep: index) else { return }
        children.remove(at: position)
    }
}
