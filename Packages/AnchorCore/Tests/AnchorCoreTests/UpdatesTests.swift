import Foundation
import Testing
@testable import AnchorCore

@Suite struct UpdatesTests {
    private func v(_ s: String) -> AppVersion { AppVersion(s)! }

    @Test func parsesVersions() {
        #expect(v("v0.1.0-beta.2").description == "0.1.0-beta.2")
        #expect(v("1.2").description == "1.2.0")
        #expect(v("1.0.0+build.5").description == "1.0.0")
        #expect(AppVersion("бета") == nil)
        #expect(AppVersion("1.0.0-") == nil)
        #expect(AppVersion("1.0.0-beta..1") == nil)
    }

    @Test func semverOrder() {
        let ordered = ["0.0.0-dev", "0.1.0-alpha", "0.1.0-beta", "0.1.0-beta.2", "0.1.0-beta.10", "0.1.0-rc.1", "0.1.0", "0.1.1", "0.2.0", "1.0.0"]
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            #expect(v(a) < v(b), "\(a) < \(b)")
            #expect(!(v(b) < v(a)), "!(\(b) < \(a))")
        }
        #expect(v("0.1.0-beta.1") < v("0.1.0-beta.1.1"))
        #expect(!(v("0.1.0") < v("0.1.0")))
    }

    private let feed = Data("""
    [
      {"tag_name": "v0.2.0-beta.1", "draft": false, "prerelease": true, "body": "жесты", "html_url": "https://example.com/b1",
       "assets": [{"name": "Anchor-0.2.0-beta.1.dmg", "browser_download_url": "https://example.com/b1.dmg"},
                  {"name": "Anchor-0.2.0-beta.1.zip", "browser_download_url": "https://example.com/b1.zip"}]},
      {"tag_name": "v0.3.0", "draft": true, "prerelease": false, "body": null, "html_url": "https://example.com/draft",
       "assets": [{"name": "Anchor-0.3.0.zip", "browser_download_url": "https://example.com/draft.zip"}]},
      {"tag_name": "v0.1.0", "draft": false, "prerelease": false, "body": null, "html_url": "https://example.com/r",
       "assets": [{"name": "Anchor-0.1.0.zip", "browser_download_url": "https://example.com/r.zip"}]},
      {"tag_name": "v0.2.5", "draft": false, "prerelease": false, "body": "", "html_url": "https://example.com/noasset",
       "assets": []}
    ]
    """.utf8)

    @Test func picksNewestWithBeta() throws {
        let update = try #require(try ReleaseFeed.update(from: feed, current: v("0.1.0-beta.2"), includePrereleases: true))
        #expect(update.version == v("0.2.0-beta.1"))
        #expect(update.downloadURL.absoluteString == "https://example.com/b1.zip")
        #expect(update.notes == "жесты")
    }

    @Test func stableOnly() throws {
        let update = try #require(try ReleaseFeed.update(from: feed, current: v("0.1.0-beta.2"), includePrereleases: false))
        #expect(update.version == v("0.1.0"))
        #expect(try ReleaseFeed.update(from: feed, current: v("0.1.0"), includePrereleases: false) == nil)
    }

    @Test func upToDate() throws {
        #expect(try ReleaseFeed.update(from: feed, current: v("0.2.0-beta.1"), includePrereleases: true) == nil)
        #expect(try ReleaseFeed.update(from: feed, current: v("1.0.0"), includePrereleases: true) == nil)
    }

    @Test func badJSONThrows() {
        #expect(throws: (any Error).self) { try ReleaseFeed.update(from: Data("{}".utf8), current: v("1.0"), includePrereleases: true) }
    }
}
