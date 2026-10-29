import SwiftUI

struct PanelRootView: View {
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
        .frame(width: 340, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.2)) { isHovering = hovering }
        }
    }
}
