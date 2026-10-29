import SwiftUI

/// Строка, которую можно свайпать двумя пальцами: едет за пальцами, под ней — подсказка действия.
private struct SwipeableRow: ViewModifier {
    let row: RowID
    @Environment(GestureController.self) private var gestures

    func body(content: Content) -> some View {
        let offset = gestures.offset(for: row)
        content
            .offset(x: offset)
            .background(alignment: offset >= 0 ? .leading : .trailing) {
                if offset != 0, let hint = gestures.hint(for: row, offset > 0 ? .right : .left) {
                    hintView(hint, offset: offset)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { gestures.register(row, frame: $0) }
            .onDisappear { gestures.unregister(row) }
    }

    private func hintView(_ hint: GestureController.Hint, offset: CGFloat) -> some View {
        let progress = min(abs(offset) / GestureController.threshold, 1)
        let color: Color = hint.isDestructive ? .red : (offset > 0 ? .green : .orange)
        return Label(hint.title, systemImage: hint.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(progress >= 1 ? color : .secondary)
            .scaleEffect(0.85 + 0.15 * progress)
            .opacity(0.3 + 0.7 * progress)
            .padding(.horizontal, 4)
    }
}

extension View {
    func swipeable(_ row: RowID) -> some View {
        modifier(SwipeableRow(row: row))
    }
}

/// Поле переименования вместо текста строки: Enter — сохранить, Esc — отменить.
struct InlineEditor: View {
    let initial: String
    let onCommit: (String) -> Void
    @Environment(AppState.self) private var state
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .onAppear {
                text = initial
                focused = true
            }
            .onSubmit {
                onCommit(text)
                state.editing = nil
            }
            .onExitCommand { state.editing = nil }
    }
}
