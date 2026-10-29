import AnchorCore
import SwiftUI

/// Свёрнутая панель: задача, следующий шаг, таймер.
struct PillView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.session.isRunning ? "scope" : "pause.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)

            if let task = state.currentTask {
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let step = task.nextStep {
                        Text("→ " + step.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(FocusClock.format(state.session.elapsed(at: context.date)))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Над чем работаем?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
        .onTapGesture { state.isPinnedExpanded.toggle() }
    }
}
