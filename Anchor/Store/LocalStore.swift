import AnchorCore
import Foundation

/// Состояние в `~/Library/Application Support/Anchor/state.json`. Позже задачи переедут в Obsidian.
struct LocalStore {
    struct Snapshot: Codable {
        var tasks: [AnchorTask]
        var currentTaskID: String?
        var session: FocusSession
        /// Необязательное: в состояниях до 0.3 его нет.
        var parked: [ParkedThought]?
    }

    let url: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = support.appending(path: "Anchor/state.json")
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }

    func save(_ snapshot: Snapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(snapshot).write(to: url, options: .atomic)
        } catch {
            NSLog("Anchor: не удалось сохранить состояние: \(error)")
        }
    }
}
