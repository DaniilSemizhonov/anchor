import AnchorCore
import SwiftUI

/// Развёрнутая панель: шаги текущей задачи, быстрый ввод, что дальше.
struct ExpandedView: View {
    @Environment(AppState.self) private var state
    @Binding var draft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let task = state.currentTask {
                currentTask(task)
            }

            TextField("Новая задача: «доклад пт #учёба !»", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    state.capture(draft)
                    draft = ""
                }

            if !state.upcoming.isEmpty {
                upcoming
            }
        }
        .padding(14)
    }

    private func currentTask(_ task: AnchorTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(task.steps.enumerated()), id: \.offset) { index, step in
                Button {
                    state.toggleStep(at: index)
                } label: {
                    Label(step.title, systemImage: step.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.isDone ? .secondary : .primary)
                        .strikethrough(step.isDone)
                }
                .buttonStyle(.plain)
            }

            if let crumb = task.lastCrumb {
                Text("📍 " + crumb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Готово", systemImage: "checkmark") { state.completeCurrentTask() }
                Button(state.session.isRunning ? "Пауза" : "Продолжить",
                       systemImage: state.session.isRunning ? "pause" : "play") { state.togglePause() }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Дальше")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(state.upcoming) { task in
                Button {
                    state.focus(on: task.id)
                } label: {
                    HStack {
                        Text(task.title).lineLimit(1)
                        Spacer()
                        if let due = task.due {
                            Text(due.shortLabel(relativeTo: state.today))
                                .font(.caption)
                                .foregroundStyle(due < state.today ? .red : .secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
