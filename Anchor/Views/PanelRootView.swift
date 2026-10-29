import SwiftUI

struct PanelRootView: View {
    /// Окно рассчитано на самую широкую карточку из настроек.
    static let maxWidth = CGFloat(PanelDefaults.widthRange.upperBound)
    /// Прозрачные поля вокруг карточки — место под тень.
    static let margin: CGFloat = 14
    /// Высота окна: с запасом под развёрнутую карточку.
    static let maxHeight: CGFloat = 560

    /// Сообщает контроллеру, где карточка, чтобы тот отслеживал наведение и пропускал клики мимо неё.
    var onCardFrameChange: @MainActor (CGRect) -> Void

    @Environment(AppState.self) private var state
    @State private var draft = ""
    @AppStorage(AppearanceKeys.width) private var width = PanelDefaults.width

    /// Не сворачиваемся, пока в поле ввода что-то набрано или строка переименовывается.
    private var isExpanded: Bool {
        state.isHovering || state.isPinnedExpanded || !draft.isEmpty || state.editing != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PillView()
            if isExpanded {
                Divider().padding(.horizontal, 12)
                ExpandedView(draft: $draft)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -6)),
                        removal: .opacity
                    ))
            }
            if let undo = state.undo {
                undoBar(undo)
                    .transition(.opacity)
            }
        }
        .frame(width: width, alignment: .leading)
        .panelBackground()
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onCardFrameChange($0) }
        .animation(.snappy(duration: 0.25), value: isExpanded)
        .animation(.snappy(duration: 0.25), value: state.undo?.message)
        .padding(Self.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Панель почти никогда не ключевое окно — без этого кнопки выглядят выключенными.
        .environment(\.controlActiveState, .key)
    }

    private func undoBar(_ undo: AppState.UndoEntry) -> some View {
        HStack {
            Text(undo.message)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Отменить") {
                withAnimation(.snappy) { state.performUndo() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5))
    }
}
