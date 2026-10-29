import KeyboardShortcuts

// macOS 15+ не даёт регистрировать глобальные сочетания только с ⌥ или ⌥⇧,
// поэтому по умолчанию везде ⌃⌥.
extension KeyboardShortcuts.Name {
    static let quickCapture = Self("quickCapture", default: .init(.space, modifiers: [.control, .option]))
    static let leaveCrumb = Self("leaveCrumb", default: .init(.b, modifiers: [.control, .option]))
    static let completeStep = Self("completeStep", default: .init(.d, modifiers: [.control, .option]))
    static let togglePanel = Self("togglePanel", default: .init(.h, modifiers: [.control, .option]))
}
