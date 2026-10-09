import XCTest
@testable import BTAudioIdleDisconnect

final class SemanticVersionTests: XCTestCase {
    func testOrderingIsNumericNotLexical() {
        XCTAssertLessThan(SemanticVersion("1.9.2")!, SemanticVersion("1.10.0")!)
        XCTAssertLessThan(SemanticVersion("1.1.0")!, SemanticVersion("1.2.0")!)
        XCTAssertLessThan(SemanticVersion("1.2.9")!, SemanticVersion("2")!)
        XCTAssertFalse(SemanticVersion("1.2.0")! < SemanticVersion("1.2.0")!)
    }

    func testMissingComponentsCountAsZero() {
        XCTAssertEqual(SemanticVersion("1.1")!, SemanticVersion("1.1.0")!)
        XCTAssertFalse(SemanticVersion("1.1")! < SemanticVersion("1.1.0")!)
    }

    func testPrefixAndSuffixAreIgnored() {
        XCTAssertEqual(SemanticVersion("v1.2.0")!, SemanticVersion("1.2.0")!)
        XCTAssertEqual(SemanticVersion("1.2.0-beta.1")!, SemanticVersion("1.2.0")!)
        XCTAssertEqual(SemanticVersion("V1.2+3")!.description, "1.2")
    }

    func testRejectsGarbage() {
        XCTAssertNil(SemanticVersion(""))
        XCTAssertNil(SemanticVersion("latest"))
        XCTAssertNil(SemanticVersion("1..2"))
        XCTAssertNil(SemanticVersion("1.x"))
    }
}

final class ReleaseEvaluationTests: XCTestCase {
    /// Trimmed copy of the real `releases/latest` payload for v1.1.0.
    private let sample = """
    {
      "tag_name": "v1.1.0",
      "name": "v1.1.0 — the notification no longer cancels its own disconnect",
      "html_url": "https://github.com/jash90/bt-audio-idle-disconnect/releases/tag/v1.1.0",
      "draft": false,
      "prerelease": false,
      "body": "## The bug\\n\\nSome **notes**.",
      "assets": [
        {
          "name": "BT.Audio.Idle.1.1.0.dmg",
          "size": 2721046,
          "content_type": "application/x-apple-diskimage",
          "digest": "sha256:f5c3d934ee6be0b288c3db889def3c666f4b6d91c52ca765b7429c56f926a383",
          "browser_download_url": "https://github.com/jash90/bt-audio-idle-disconnect/releases/download/v1.1.0/BT.Audio.Idle.1.1.0.dmg"
        }
      ]
    }
    """.data(using: .utf8)!

    func testNewerReleaseIsReported() throws {
        let result = UpdateChecker.evaluate(data: sample, statusCode: 200, error: nil, current: SemanticVersion("1.0.0")!)
        let release = try XCTUnwrap(try result.get())
        XCTAssertEqual(release.displayVersion, "1.1.0")
        XCTAssertEqual(release.dmgAsset?.name, "BT.Audio.Idle.1.1.0.dmg")
        XCTAssertEqual(release.dmgAsset?.size, 2721046)
        XCTAssertEqual(release.dmgAsset?.sha256, "f5c3d934ee6be0b288c3db889def3c666f4b6d91c52ca765b7429c56f926a383")
    }

    func testSameOrOlderReleaseIsUpToDate() throws {
        XCTAssertNil(try UpdateChecker.evaluate(data: sample, statusCode: 200, error: nil, current: SemanticVersion("1.1.0")!).get())
        XCTAssertNil(try UpdateChecker.evaluate(data: sample, statusCode: 200, error: nil, current: SemanticVersion("1.2.0")!).get())
    }

    func testHTTPFailuresMapToErrors() {
        let current = SemanticVersion("1.0.0")!
        XCTAssertEqual(failure(UpdateChecker.evaluate(data: nil, statusCode: 403, error: nil, current: current)), .rateLimited)
        XCTAssertEqual(failure(UpdateChecker.evaluate(data: nil, statusCode: 429, error: nil, current: current)), .rateLimited)
        XCTAssertEqual(failure(UpdateChecker.evaluate(data: nil, statusCode: 404, error: nil, current: current)), .noRelease)
        XCTAssertEqual(failure(UpdateChecker.evaluate(data: nil, statusCode: 500, error: nil, current: current)), .badResponse(500))
        XCTAssertEqual(failure(UpdateChecker.evaluate(data: Data("{}".utf8), statusCode: 200, error: nil, current: current)), .invalidData)
        let offline = URLError(.notConnectedToInternet)
        guard case .network = failure(UpdateChecker.evaluate(data: nil, statusCode: nil, error: offline, current: current)) else {
            return XCTFail("expected a network error")
        }
    }

    func testDigestParsing() {
        func asset(_ digest: String?) -> Release.Asset {
            Release.Asset(name: "a.dmg", browserDownloadURL: URL(string: "https://example.com/a.dmg")!, size: 1, digest: digest)
        }
        XCTAssertNil(asset(nil).sha256)
        XCTAssertNil(asset("md5:abcd").sha256)
        XCTAssertNil(asset("sha256:abcd").sha256)
        XCTAssertEqual(asset("SHA256:" + String(repeating: "AB", count: 32)).sha256, String(repeating: "ab", count: 32))
    }

    func testDmgAssetSkipsOtherFiles() throws {
        let json = """
        {"tag_name":"v2.0.0","name":null,"body":null,"html_url":"https://example.com","assets":[
          {"name":"notes.txt","size":1,"digest":null,"browser_download_url":"https://example.com/notes.txt"},
          {"name":"App 2.0.0.DMG","size":2,"digest":null,"browser_download_url":"https://example.com/app.dmg"}
        ]}
        """
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))
        XCTAssertEqual(release.dmgAsset?.name, "App 2.0.0.DMG")
    }

    func testSHA256OfFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("btaid-sha-\(UUID().uuidString)")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try UpdateChecker.sha256Hex(of: url), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    private func failure(_ result: Result<Release?, UpdateError>) -> UpdateError? {
        if case .failure(let e) = result { return e }
        return nil
    }
}

final class GlobalSettingsUpdateFieldsTests: XCTestCase {
    func testOldSettingsFileKeepsValuesAndGetsUpdateDefaults() throws {
        let old = #"{"globalTimeoutSeconds": 900, "devices": [{"address": "aa", "name": "X", "enabled": false}]}"#
        let s = try JSONDecoder().decode(GlobalSettings.self, from: Data(old.utf8))
        XCTAssertEqual(s.globalTimeoutSeconds, 900)
        XCTAssertEqual(s.devices.count, 1)
        XCTAssertTrue(s.autoCheckForUpdates)
        XCTAssertNil(s.lastUpdateCheck)
        XCTAssertNil(s.lastNotifiedUpdateVersion)
    }

    func testUpdateFieldsRoundTrip() throws {
        var s = GlobalSettings()
        s.autoCheckForUpdates = false
        s.lastUpdateCheck = Date(timeIntervalSince1970: 1_800_000_000)
        s.lastNotifiedUpdateVersion = "1.3.0"
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }
}
