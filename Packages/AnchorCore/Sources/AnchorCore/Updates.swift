import Foundation

/// Версия вида `0.1.0`, `0.1.0-beta.2`. Сравнение — по правилам semver.
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let numbers: [Int]
    public let prerelease: [String]

    public init?(_ string: String) {
        var raw = Substring(string.trimmingCharacters(in: .whitespaces))
        if raw.hasPrefix("v") { raw = raw.dropFirst() }
        if let plus = raw.firstIndex(of: "+") { raw = raw[..<plus] }

        let parts = raw.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = parts[0].split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (1...3).contains(core.count), core.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        numbers = core.map { $0! } + Array(repeating: 0, count: 3 - core.count)

        if parts.count == 2 {
            prerelease = parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard prerelease.allSatisfy({ !$0.isEmpty }) else { return nil }
        } else {
            prerelease = []
        }
    }

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public var description: String {
        numbers.map(String.init).joined(separator: ".") + (isPrerelease ? "-" + prerelease.joined(separator: ".") : "")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        // Релиз старше любой своей беты.
        switch (lhs.isPrerelease, rhs.isPrerelease) {
        case (false, _): return false
        case (true, false): return true
        default: break
        }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            switch (Int(a), Int(b)) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a < b
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

public struct ReleaseInfo: Hashable, Sendable {
    public let version: AppVersion
    public let notes: String
    public let pageURL: URL
    public let downloadURL: URL
}

/// Релизы Anchor на GitHub.
public enum ReleaseFeed {
    public static let apiURL = URL(string: "https://api.github.com/repos/DaniilSemizhonov/anchor/releases?per_page=20")!

    private struct Release: Decodable {
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let body: String?
        let htmlUrl: URL
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: URL
    }

    /// Самый новый релиз новее `current` с zip-архивом приложения, или `nil`.
    public static func update(from json: Data, current: AppVersion, includePrereleases: Bool) throws -> ReleaseInfo? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let releases = try decoder.decode([Release].self, from: json)

        let candidates: [ReleaseInfo] = releases.compactMap { release in
            guard !release.draft, includePrereleases || !release.prerelease,
                  let version = AppVersion(release.tagName),
                  includePrereleases || !version.isPrerelease,
                  let zip = release.assets.first(where: { $0.name.hasPrefix("Anchor") && $0.name.hasSuffix(".zip") })
            else { return nil }
            return ReleaseInfo(
                version: version,
                notes: release.body ?? "",
                pageURL: release.htmlUrl,
                downloadURL: zip.browserDownloadUrl
            )
        }
        guard let newest = candidates.max(by: { $0.version < $1.version }), current < newest.version else { return nil }
        return newest
    }
}
