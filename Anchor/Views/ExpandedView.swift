import AnchorCore
import SwiftUI

/// Развёрнутая панель: шаги текущей задачи, быстрый ввод, что дальше.
struct ExpandedView: View {
    private static let upcomingLimit = 5

    @Environment(AppState.self) private var state
    @Binding var draft: String
    @State private var newStep = ""
    @State private var showAllUpcoming = false
    @State private var showParked = false
    @AppStorage(AppearanceKeys.showAddStep) private var showAddStep = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let task = state.currentTask {
                currentTask(task)
            }

            TextField("Новая задача: «доклад пт #учёба !»", text: $draft)
                .textFieldStyle(.roundedBorder)
                // ⌘Enter — сразу сделать текущей.
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    submitDraft(makeCurrent: true)
                    return .handled
                }
                .onSubmit { submitDraft(makeCurrent: false) }

            if !state.upcoming.isEmpty || state.doneTodayCount > 0 {
                upcoming
            }

            if !state.parked.isEmpty {
                parking
            }
        }
        .padding(14)
    }

    private func submitDraft(makeCurrent: Bool) {
        withAnimation(.snappy) { state.capture(draft, makeCurrent: makeCurrent) }
        draft = ""
    }

    // MARK: - Текущая задача

    private func currentTask(_ task: AnchorTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(task.steps.enumerated()), id: \.offset) { index, step in
                stepRow(step, index: index)
            }

            if showAddStep {
                TextField("+ шаг", text: $newStep)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.leading, 24)
                    .onSubmit {
                        withAnimation(.snappy) { state.addStep(newStep) }
                        newStep = ""
                    }
            }

            if let crumb = task.lastCrumb {
                Text("📍 " + crumb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Готово", systemImage: "checkmark") {
                    withAnimation(.snappy) { state.complete(task.id) }
                }
                Button(state.session.isRunning ? "Пауза" : "Продолжить",
                       systemImage: state.session.isRunning ? "pause" : "play") { state.togglePause() }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func stepRow(_ step: TaskStep, index: Int) -> some View {
        if state.editing == .step(index) {
            Label {
                InlineEditor(initial: step.title) { state.renameStep(at: index, to: $0) }
            } icon: {
                Image(systemName: "circle")
            }
        } else {
            Button {
                withAnimation(.snappy) { state.toggleStep(at: index) }
            } label: {
                Label(step.title, systemImage: step.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.isDone ? .secondary : .primary)
                    .strikethrough(step.isDone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeable(.step(index))
            .contextMenu {
                Button("Переименовать", systemImage: "pencil") { state.editing = .step(index) }
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    withAnimation(.snappy) { state.removeStep(at: index) }
                }
            }
        }
    }

    // MARK: - Дальше

    private var upcoming: some View {
        let all = state.upcoming
        let shown = showAllUpcoming ? all : Array(all.prefix(Self.upcomingLimit))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Дальше")
                Spacer()
                if state.doneTodayCount > 0 {
                    Text("✓ сегодня: \(state.doneTodayCount)")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(shown) { task in
                taskRow(task)
            }

            if all.count > Self.upcomingLimit {
                Button(showAllUpcoming ? "Свернуть" : "Ещё \(all.count - Self.upcomingLimit)") {
                    withAnimation(.snappy) { showAllUpcoming.toggle() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: AnchorTask) -> some View {
        if state.editing == .task(task.id) {
            InlineEditor(initial: task.title) { state.rename(task.id, to: $0) }
        } else {
            Button {
                withAnimation(.snappy) { state.focus(on: task.id) }
            } label: {
                HStack {
                    if task.priority > .none {
                        Image(systemName: "exclamationmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
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
            .swipeable(.task(task.id))
            .contextMenu {
                Button("Сделать текущей", systemImage: "scope") { state.focus(on: task.id) }
                Button("Готово", systemImage: "checkmark") { withAnimation(.snappy) { state.complete(task.id) } }
                Menu("Отложить") {
                    ForEach(PostponeOption.allCases, id: \.self) { option in
                        Button(option.title) { withAnimation(.snappy) { state.postpone(task.id, option) } }
                    }
                }
                Button("Переименовать", systemImage: "pencil") { state.editing = .task(task.id) }
                Divider()
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    withAnimation(.snappy) { state.delete(task.id) }
                }
            }
        }
    }

    // MARK: - Парковка

    private var parking: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy) { showParked.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showParked ? 90 : 0))
                    Text("Парковка · \(state.parked.count)")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            if showParked {
                ForEach(state.parked) { thought in
                    Text(thought.text)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .swipeable(.parked(thought.id))
                        .contextMenu {
                            Button("Сделать задачей", systemImage: "tray.and.arrow.up") {
                                withAnimation(.snappy) { state.promoteParked(thought.id) }
                            }
                            Button("Удалить", systemImage: "trash", role: .destructive) {
                                withAnimation(.snappy) { state.deleteParked(thought.id) }
                            }
                        }
                }
            }
        }
    }
}
