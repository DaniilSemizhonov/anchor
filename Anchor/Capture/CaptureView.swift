import AnchorCore
import SwiftUI

struct CaptureView: View {
    let mode: CaptureController.Mode
    let initialText: String
    let onClose: () -> Void

    @Environment(AppState.self) private var state
    @State private var text = ""
    /// Return может прийти и через onKeyPress, и через onSubmit — добавляем один раз.
    @State private var submitted = false
    @FocusState private var focused: Bool

    private var draft: CaptureDraft {
        QuickCaptureParser().parse(text, today: state.today)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Клик по прозрачной области вокруг карточки закрывает окно.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            card
                .frame(width: 600)
                .panelBackground()
                .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
                .padding(.top, 8)
        }
        .onAppear {
            text = initialText
            Task { focused = true }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: mode == .task ? "plus.circle.fill" : "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .lineLimit(1...6)
                    .focused($focused)
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            text += "\n"
                        } else {
                            let makeCurrent = press.modifiers.contains(.command)
                            afterTextSettles { submit(makeCurrent: makeCurrent) }
                        }
                        return .handled
                    }
                    .onSubmit { afterTextSettles { submit(makeCurrent: false) } }
                    .onKeyPress(.tab, phases: .down) { _ in
                        guard mode == .task else { return .ignored }
                        afterTextSettles {
                            guard !submitted else { return }
                            submitted = true
                            state.park(text)
                            onClose()
                        }
                        return .handled
                    }
                    .onExitCommand(perform: onClose)
            }

            if mode == .task, !text.isEmpty {
                preview
            }

            Text(hints)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
    }

    private var placeholder: String {
        switch mode {
        case .task:
            "Новая задача: «доклад к пятнице #учёба !»"
        case .crumb:
            state.currentTask.map { "Где остановился в «\($0.title)»?" } ?? "Сначала выбери текущую задачу"
        }
    }

    private var hints: String {
        switch mode {
        case .task: "↩ добавить · ⌘↩ сделать текущей · ⇥ в парковку · ⇧↩ шаг · esc закрыть"
        case .crumb: "↩ сохранить · esc закрыть"
        }
    }

    /// Что поймёт парсер: дата, приоритет, теги, шаги.
    private var preview: some View {
        let draft = draft
        return HStack(spacing: 6) {
            if let due = draft.due {
                chip(due.shortLabel(relativeTo: state.today), systemImage: "calendar")
            }
            if draft.priority > .none {
                chip(draft.priority == .highest ? "очень важно" : "важно", systemImage: "exclamationmark")
            }
            ForEach(draft.tags, id: \.self) { tag in
                chip("#" + tag, systemImage: nil)
            }
            if !draft.steps.isEmpty {
                chip("шагов: \(draft.steps.count)", systemImage: "list.bullet")
            }
            if draft.title.isEmpty {
                Text("нет названия").font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func chip(_ title: String, systemImage: String?) -> some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.tint.opacity(0.15), in: Capsule())
    }

    /// Если нажать Enter сразу после последней буквы, поле ещё не успело передать текст
    /// в `text` — и задача терялась. Ждём один такт, пока текст дойдёт.
    private func afterTextSettles(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            action()
        }
    }

    private func submit(makeCurrent: Bool) {
        guard !submitted else { return }
        switch mode {
        case .task:
            guard !draft.title.isEmpty else { return }
            withAnimation(.snappy) { state.capture(text, makeCurrent: makeCurrent) }
        case .crumb:
            state.addCrumb(text)
        }
        submitted = true
        onClose()
    }
}
