import SwiftUI

struct PanelRootView: View {
    static let width: CGFloat = 340

    /// Сообщает контроллеру размер содержимого, чтобы тот подогнал окно.
    var onSizeChange: @MainActor (CGSize) -> Void

    @Environment(AppState.self) private var state
    @State private var isHovering = false
    @State private var draft = ""

    /// Не сворачиваемся, пока в поле ввода что-то набрано.
    private var isExpanded: Bool {
        isHovering || state.isPinnedExpanded || !draft.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PillView()
            if isExpanded {
                Divider().padding(.horizontal, 12)
                ExpandedView(draft: $draft)
                    .transition(.opacity)
            }
        }
        .frame(width: Self.width, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.2)) { isHovering = hovering }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
