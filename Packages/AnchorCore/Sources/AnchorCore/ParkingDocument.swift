import Foundation

/// Файл парковки: мысли — пункты `- текст` без отступа (не `- [ ]`, чтобы Tasks не считал их задачами).
/// Остальной текст файла (frontmatter, заголовки, заметки) сохраняется как есть.
public struct ParkingDocument: Sendable {
    private enum Segment: Sendable {
        case text(String)
        case item(String)
    }

    private var segments: [Segment]
    private let endsWithNewline: Bool

    public init(markdown: String) {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        endsWithNewline = markdown.hasSuffix("\n")
        if endsWithNewline { lines.removeLast() }
        segments = lines.map { line in
            if let item = Self.item(line) { .item(item) } else { .text(line) }
        }
    }

    public var items: [String] {
        segments.compactMap { if case .item(let text) = $0 { text } else { nil } }
    }

    /// Заменяет пункты на `items`: новые стоят там, где был первый пункт, или в конце файла.
    public mutating func sync(with items: [String]) {
        guard items != self.items else { return }
        let firstItem = segments.firstIndex { if case .item = $0 { true } else { false } }
        segments.removeAll { if case .item = $0 { true } else { false } }
        let position = firstItem.map { min($0, segments.count) } ?? segments.count
        segments.insert(contentsOf: items.map { .item($0.replacingOccurrences(of: "\n", with: " ")) }, at: position)
    }

    public func render() -> String {
        let text = segments.map { segment in
            switch segment {
            case .text(let line): line
            case .item(let item): "- " + item
            }
        }
        .joined(separator: "\n")
        return endsWithNewline || segments.isEmpty ? text + "\n" : text
    }

    private static func item(_ line: String) -> String? {
        guard line.hasPrefix("- "), !line.hasPrefix("- [") else { return nil }
        let text = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
