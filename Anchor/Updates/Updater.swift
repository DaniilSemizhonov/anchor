import AnchorCore
import AppKit
import Observation

enum SettingsKeys {
    static let autoCheckUpdates = "updates.autoCheck"
    static let includeBeta = "updates.includeBeta"
}

/// Проверяет релизы на GitHub и ставит новую версию.
@MainActor
@Observable
final class Updater {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case installing
        case failed(String)
    }

    private(set) var status: Status = .idle
    let currentVersion: AppVersion

    @ObservationIgnored private var timer: Timer?

    init() {
        // AnchorVersion подставляет CI из тега; у локальных сборок — `…-dev`.
        let raw = Bundle.main.object(forInfoDictionaryKey: "AnchorVersion") as? String
        currentVersion = raw.flatMap(AppVersion.init) ?? AppVersion("0.0.0-dev")!
        UserDefaults.standard.register(defaults: [
            SettingsKeys.autoCheckUpdates: true,
            SettingsKeys.includeBeta: true,
        ])
    }

    var availableRelease: ReleaseInfo? {
        if case .available(let release) = status { release } else { nil }
    }

    /// Проверка при запуске и раз в 6 часов, если включена в настройках.
    func startAutomaticChecks() {
        let timer = Timer(timeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAutomatically() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        checkAutomatically()
    }

    func check() {
        Task { await check(silent: false) }
    }

    func install(_ release: ReleaseInfo) {
        guard status != .installing else { return }
        status = .installing
        Task {
            do {
                try await UpdateInstaller.install(from: release.downloadURL)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func checkAutomatically() {
        guard UserDefaults.standard.bool(forKey: SettingsKeys.autoCheckUpdates) else { return }
        Task { await check(silent: true) }
    }

    private func check(silent: Bool) async {
        switch status {
        case .checking, .installing: return
        default: break
        }
        status = .checking
        do {
            var request = URLRequest(url: ReleaseFeed.apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.server
            }
            let includeBeta = UserDefaults.standard.bool(forKey: SettingsKeys.includeBeta)
            if let release = try ReleaseFeed.update(from: data, current: currentVersion, includePrereleases: includeBeta) {
                status = .available(release)
            } else {
                status = .upToDate
            }
        } catch {
            status = silent ? .idle : .failed(error.localizedDescription)
        }
    }
}

enum UpdateError: LocalizedError {
    case server
    case notWritable
    case badArchive

    var errorDescription: String? {
        switch self {
        case .server: "GitHub не ответил, попробуйте позже."
        case .notWritable: "Нет прав заменить приложение. Перенесите Anchor в «Программы»."
        case .badArchive: "В скачанном архиве нет Anchor."
        }
    }
}

/// Скачивает zip релиза, распаковывает и после выхода приложения подменяет его новой версией.
/// Файлы, скачанные самим приложением, не получают карантин, поэтому Gatekeeper не ругается.
enum UpdateInstaller {
    @MainActor
    static func install(from url: URL) async throws {
        let fileManager = FileManager.default
        let target = Bundle.main.bundleURL
        guard fileManager.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable
        }

        let (archive, _) = try await URLSession.shared.download(from: url)
        let work = fileManager.temporaryDirectory.appending(path: "AnchorUpdate-\(UUID().uuidString)")
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        try await run("/usr/bin/ditto", ["-x", "-k", archive.path, work.path])
        try? fileManager.removeItem(at: archive)

        let newApp = work.appending(path: "Anchor.app")
        guard let bundle = Bundle(url: newApp), bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.badArchive
        }

        // Ждём выхода, меняем бандл (со страховкой на случай ошибки) и запускаем новую версию.
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$2.old"; then
          if mv "$3" "$2"; then rm -rf "$2.old"; else mv "$2.old" "$2"; fi
        fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        rm -rf "$4"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", script, "anchor-update",
            String(ProcessInfo.processInfo.processIdentifier), target.path, newApp.path, work.path,
        ]
        try process.run()
        NSApplication.shared.terminate(nil)
    }

    private static func run(_ tool: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.badArchive)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
