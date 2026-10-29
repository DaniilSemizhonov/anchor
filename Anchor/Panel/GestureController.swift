import AppKit
import Observation
import SwiftUI

/// Свайпы двумя пальцами по строкам и скролл по таблетке.
///
/// SwiftUI на macOS не даёт свайпов вне `List`, поэтому ловим события скролла окна панели
/// сами: строки сообщают свои рамки, а мы решаем, какую двигать и что делать в конце.
@MainActor
@Observable
final class GestureController {
    enum Direction {
        case right, left
    }

    struct Hint {
        let title: String
        let systemImage: String
        let isDestructive: Bool
    }

    /// Порог, после которого отпускание выполняет действие.
    static let threshold: CGFloat = 64
    /// Шаг вертикального скролла по таблетке для переключения задачи.
    private static let switchStep: CGFloat = 50

    private(set) var activeRow: RowID?
    private(set) var offset: CGFloat = 0

    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private let state: AppState
    /// Рамки строк в координатах окна SwiftUI (начало сверху слева).
    @ObservationIgnored private var rowFrames: [RowID: CGRect] = [:]
    @ObservationIgnored private var tracking: Tracking?
    @ObservationIgnored private var lastWheelSwitch = Date.distantPast

    private struct Tracking {
        let row: RowID
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var axis: Axis?
        var switchedBy: CGFloat = 0
        var passedThreshold = false

        enum Axis { case horizontal, vertical }
    }

    init(state: AppState) {
        self.state = state
    }

    func register(_ row: RowID, frame: CGRect) {
        rowFrames[row] = frame
    }

    func unregister(_ row: RowID) {
        rowFrames[row] = nil
    }

    func offset(for row: RowID) -> CGFloat {
        activeRow == row ? offset : 0
    }

    /// Что произойдёт при свайпе строки в эту сторону; `nil` — действия нет.
    func hint(for row: RowID, _ direction: Direction) -> Hint? {
        switch (row, direction) {
        case (.pill, .right):
            state.currentTask?.nextStep != nil
                ? Hint(title: "Шаг готов", systemImage: "checkmark", isDestructive: false)
                : Hint(title: "Готово", systemImage: "checkmark", isDestructive: false)
        case (.pill, .left), (.task, .left):
            Hint(title: "Завтра", systemImage: "moon.zzz", isDestructive: false)
        case (.step(let index), .right):
            state.currentTask?.steps[safe: index]?.isDone == true
                ? Hint(title: "Вернуть", systemImage: "arrow.uturn.backward", isDestructive: false)
                : Hint(title: "Готово", systemImage: "checkmark", isDestructive: false)
        case (.step, .left):
            Hint(title: "Удалить", systemImage: "trash", isDestructive: true)
        case (.task, .right):
            Hint(title: "Готово", systemImage: "checkmark", isDestructive: false)
        }
    }

    // MARK: - События

    /// Возвращает `true`, если событие обработано и дальше его передавать не надо.
    func handle(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, let content = window.contentView else { return false }
        let point = CGPoint(x: event.locationInWindow.x, y: content.bounds.height - event.locationInWindow.y)

        // Инерция после жеста нам не нужна.
        if event.momentumPhase != [] { return false }

        // Колесо мыши: без фаз, только переключение задач над таблеткой.
        guard event.hasPreciseScrollingDeltas, event.phase != [] else {
            return handleWheel(event, at: point)
        }

        // Направление пальцев не зависит от «естественной прокрутки».
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let fingerDX = event.scrollingDeltaX * sign
        let fingerDY = event.scrollingDeltaY * sign

        switch event.phase {
        case .began:
            guard let row = row(at: point) else { return false }
            tracking = Tracking(row: row)
            return true
        case .changed:
            guard var current = tracking else { return false }
            current.dx += fingerDX
            current.dy += fingerDY
            if current.axis == nil, abs(current.dx) + abs(current.dy) > 6 {
                current.axis = abs(current.dx) > abs(current.dy) ? .horizontal : .vertical
            }
            switch current.axis {
            case .horizontal: updateSwipe(&current)
            case .vertical where current.row == .pill: updateSwitch(&current)
            default: break
            }
            tracking = current
            return true
        case .ended, .cancelled:
            guard let finished = tracking else { return false }
            tracking = nil
            if finished.axis == .horizontal {
                finishSwipe(finished, cancelled: event.phase == .cancelled)
            }
            return true
        default:
            return tracking != nil
        }
    }

    private func row(at point: CGPoint) -> RowID? {
        rowFrames.first { $0.value.contains(point) }?.key
    }

    private func updateSwipe(_ tracking: inout Tracking) {
        let direction: Direction = tracking.dx >= 0 ? .right : .left
        let allowed = hint(for: tracking.row, direction) != nil
        // Резиновый край: дальше порога строка идёт туже, без действия — почти не двигается.
        let raw = tracking.dx
        let limit = Self.threshold + 30
        var shown = abs(raw) <= limit ? raw : (raw > 0 ? 1 : -1) * (limit + (abs(raw) - limit) * 0.25)
        if !allowed { shown *= 0.15 }

        activeRow = tracking.row
        offset = shown

        let passed = allowed && abs(raw) >= Self.threshold
        if passed != tracking.passedThreshold {
            tracking.passedThreshold = passed
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func finishSwipe(_ tracking: Tracking, cancelled: Bool) {
        let direction: Direction = tracking.dx >= 0 ? .right : .left
        let perform = !cancelled && tracking.passedThreshold
        withAnimation(.snappy(duration: 0.25)) {
            if perform { run(tracking.row, direction) }
            offset = 0
            activeRow = nil
        }
    }

    private func updateSwitch(_ tracking: inout Tracking) {
        // Пальцы вверх — следующая задача, вниз — предыдущая.
        let steps = Int((-tracking.dy - tracking.switchedBy) / Self.switchStep)
        guard steps != 0 else { return }
        let direction = steps > 0 ? 1 : -1
        tracking.switchedBy += CGFloat(direction) * Self.switchStep
        if withAnimation(.snappy(duration: 0.2), { state.switchTask(by: direction) }) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    private func handleWheel(_ event: NSEvent, at point: CGPoint) -> Bool {
        guard row(at: point) == .pill, event.scrollingDeltaY != 0 else { return false }
        guard Date.now.timeIntervalSince(lastWheelSwitch) > 0.25 else { return true }
        lastWheelSwitch = .now
        withAnimation(.snappy(duration: 0.2)) {
            _ = state.switchTask(by: event.scrollingDeltaY < 0 ? 1 : -1)
        }
        return true
    }

    private func run(_ row: RowID, _ direction: Direction) {
        switch (row, direction) {
        case (.pill, .right): state.completeNextStepOrTask()
        case (.pill, .left): if let id = state.currentTaskID { state.postpone(id, .tomorrow) }
        case (.step(let index), .right): state.toggleStep(at: index)
        case (.step(let index), .left): state.removeStep(at: index)
        case (.task(let id), .right): state.complete(id)
        case (.task(let id), .left): state.postpone(id, .tomorrow)
        }
    }
}
