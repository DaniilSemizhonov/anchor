import KeyboardShortcuts

// macOS 15+ не даёт регистрировать глобальные сочетания только с ⌥ или ⌥⇧,
// поэтому по умолчанию везде ⌃⌥.
extension KeyboardShortcuts.Name {
    static let quickCapture = Self("quickCapture", initial: .init(.space, modifiers: [.control, .option]))
    static let leaveCrumb = Self("leaveCrumb", initial: .init(.b, modifiers: [.control, .option]))
    static let completeStep = Self("completeStep", initial: .init(.d, modifiers: [.control, .option]))
    static let togglePanel = Self("togglePanel", initial: .init(.h, modifiers: [.control, .option]))
}
