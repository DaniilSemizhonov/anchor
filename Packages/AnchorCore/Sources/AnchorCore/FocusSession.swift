import Foundation

/// Сколько времени я на текущей задаче. Таймер можно ставить на паузу.
public struct FocusSession: Codable, Hashable, Sendable {
    public private(set) var taskID: String?
    /// С какого момента идёт отсчёт; `nil` — на паузе.
    public private(set) var runningSince: Date?
    public private(set) var accumulated: TimeInterval = 0

    public init() {}

    public var isRunning: Bool { runningSince != nil }

    /// Переключиться на задачу. Для другой задачи таймер начинается с нуля.
    public mutating func focus(on taskID: String, at now: Date) {
        if taskID != self.taskID {
            self.taskID = taskID
            accumulated = 0
            runningSince = now
        } else if runningSince == nil {
            runningSince = now
        }
    }

    public mutating func pause(at now: Date) {
        guard let since = runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(since))
        runningSince = nil
    }

    public mutating func resume(at now: Date) {
        guard taskID != nil, runningSince == nil else { return }
        runningSince = now
    }

    public mutating func stop() {
        self = FocusSession()
    }

    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + max(0, runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }
}

public enum FocusClock {
    /// «<1 мин», «23 мин», «1 ч 05 мин».
    public static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return "<1 мин" }
        if minutes < 60 { return "\(minutes) мин" }
        return "\(minutes / 60) ч " + String(format: "%02d", minutes % 60) + " мин"
    }
}
