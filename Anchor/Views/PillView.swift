import AnchorCore
import SwiftUI

/// Свёрнутая панель: задача, следующий шаг, таймер.
/// Свайп вправо — шаг готов, влево — на завтра, скролл вверх/вниз — другая задача.
struct PillView: View {
    @Environment(AppState.self) private var state
    @AppStorage(AppearanceKeys.textSize) private var textSize = PanelTextSize.regular
    @AppStorage(AppearanceKeys.showTimer) private var showTimer = true
    @AppStorage(AppearanceKeys.showStep) private var showStep = true

    private func size(_ base: CGFloat) -> CGFloat { base * textSize.scale }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.session.isRunning ? "scope" : "pause.circle")
                .font(.system(size: size(15), weight: .semibold))
                .foregroundStyle(.tint)

            if let task = state.currentTask {
                VStack(alignment: .leading, spacing: 1) {
                    if state.editing == .pill {
                        InlineEditor(initial: task.title) { state.rename(task.id, to: $0) }
                            .font(.system(size: size(13), weight: .semibold))
                    } else {
                        Text(task.title)
                            .font(.system(size: size(13), weight: .semibold))
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                    if showStep, let step = task.nextStep {
                        Text("→ " + step.title)
                            .font(.system(size: size(11)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                }
                .id(task.id)
                .transition(.push(from: .bottom))
                Spacer(minLength: 8)
                if showTimer {
                    TimelineView(.periodic(from: .now, by: 15)) { context in
                        Text(FocusClock.format(state.session.elapsed(at: context.date)))
                            .font(.system(size: size(12), weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Над чем работаем?")
                    .font(.system(size: size(13), weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .clipped()
        .swipeable(.pill)
        .gesture(WindowDragGesture())
        .onTapGesture { state.isPinnedExpanded.toggle() }
        .contextMenu { menu }
    }

    @ViewBuilder
    private var menu: some View {
        if let task = state.currentTask {
            Button("Готово", systemImage: "checkmark") { state.complete(task.id) }
            Menu("Отложить") {
                ForEach(PostponeOption.allCases, id: \.self) { option in
                    Button(option.title) { state.postpone(task.id, option) }
                }
            }
            Button("Переименовать", systemImage: "pencil") { state.editing = .pill }
            Button(state.session.isRunning ? "Пауза" : "Продолжить",
                   systemImage: state.session.isRunning ? "pause" : "play") { state.togglePause() }
            Divider()
            Button("Удалить", systemImage: "trash", role: .destructive) { state.delete(task.id) }
        }
        Button(state.isPinnedExpanded ? "Не держать раскрытой" : "Держать раскрытой") {
            state.isPinnedExpanded.toggle()
        }
    }
}
