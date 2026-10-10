import XCTest
@testable import BTAudioIdleDisconnect

/// Keeps Resources/en.lproj and Resources/pl.lproj complete and consistent with the code.
final class LocalizationTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let languages = ["en", "pl"]

    private func table(_ lang: String, _ name: String) throws -> [String: String] {
        let url = Self.repoRoot.appendingPathComponent("Resources/\(lang).lproj/\(name).strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String], "\(url.path) is not a string table")
    }

    /// Format specifiers keyed by argument position, e.g. "%2$ld" → [2: "ld"].
    private func specifiers(_ s: String) -> [Int: String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?((?:ll|l|hh|h|q|z|t|j)?[@dDiuUxXoOfFeEgGcCsSaAp])"#)
        var result: [Int: String] = [:]
        var next = 1
        let ns = s.replacingOccurrences(of: "%%", with: "") as NSString
        for m in regex.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)) {
            let posRange = m.range(at: 1)
            let pos = posRange.location == NSNotFound ? next : Int(ns.substring(with: posRange))!
            next = pos + 1
            result[pos] = ns.substring(with: m.range(at: 2))
        }
        return result
    }

    func testAllLanguagesHaveTheSameKeys() throws {
        for name in ["Localizable", "InfoPlist"] {
            let en = try table("en", name)
            XCTAssertFalse(en.isEmpty, "\(name): empty English table")
            for lang in Self.languages where lang != "en" {
                let other = try table(lang, name)
                XCTAssertEqual(Set(other.keys).subtracting(en.keys), [], "\(lang)/\(name): keys missing in en")
                XCTAssertEqual(Set(en.keys).subtracting(other.keys), [], "\(lang)/\(name): untranslated keys")
                for (key, value) in other {
                    XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(lang): empty value for \(key)")
                }
            }
        }
    }

    func testEnglishValuesEqualKeys() throws {
        for (key, value) in try table("en", "Localizable") {
            XCTAssertEqual(key, value, "English text is the key, so the table must not diverge from it")
        }
    }

    func testFormatSpecifiersMatch() throws {
        let en = try table("en", "Localizable")
        for lang in Self.languages where lang != "en" {
            for (key, value) in try table(lang, "Localizable") {
                XCTAssertEqual(specifiers(value), specifiers(key), "\(lang): format specifiers differ for \"\(key)\"")
            }
        }
        XCTAssertEqual(specifiers("%1$@ in %2$lds"), [1: "@", 2: "ld"])
        XCTAssertEqual(specifiers("za %2$ld s: %1$@ 50%%"), [1: "@", 2: "ld"])
        XCTAssertFalse(en.isEmpty)
    }

    /// Every L10n.tr("…") literal in the sources has an entry, and the table has no stale keys.
    func testSourceKeysAreTranslated() throws {
        let sources = Self.repoRoot.appendingPathComponent("Sources/BTAudioIdleDisconnect")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let regex = try NSRegularExpression(pattern: #"L10n\.tr\("((?:[^"\\]|\\.)*)""#)
        var used = Set<String>()
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let raw = String(text[Range(m.range(at: 1), in: text)!])
                used.insert(raw.replacingOccurrences(of: #"\""#, with: "\"").replacingOccurrences(of: #"\\"#, with: #"\"#))
            }
        }
        XCTAssertGreaterThan(used.count, 50)
        let en = Set(try table("en", "Localizable").keys)
        XCTAssertEqual(used.subtracting(en), [], "used in code but missing from Localizable.strings")
        XCTAssertEqual(en.subtracting(used), [], "in Localizable.strings but not used in code")
    }

    func testPolishLookupAndFormatting() throws {
        let saved = L10n.bundle
        defer { L10n.bundle = saved }
        L10n.bundle = try XCTUnwrap(Bundle(url: Self.repoRoot.appendingPathComponent("Resources/pl.lproj")))
        XCTAssertEqual(L10n.tr("Quit"), "Zakończ")
        XCTAssertEqual(L10n.tr("Status: disconnecting in %lds", 30), "Stan: rozłączenie za 30 s")
        XCTAssertEqual(L10n.tr("Status: idle — %ld:%02ld remaining", 4, 5), "Stan: cisza — zostało 4:05")
        XCTAssertEqual(L10n.tr("%1$@ will be disconnected in %2$lds. Tap Cancel to keep connected.", "AirPods", 15),
                       "Rozłączenie za 15 s: AirPods. Kliknij Anuluj, aby pozostać w połączeniu.")
        XCTAssertEqual(L10n.tr("Downloading Update… %ld%%", 40), "Pobieranie aktualizacji… 40%")
        XCTAssertEqual(L10n.tr("not in the table"), "not in the table", "missing keys fall back to the English key")
    }

    func testEnglishFallbackWithoutBundleResources() {
        let saved = L10n.bundle
        defer { L10n.bundle = saved }
        L10n.bundle = Bundle(for: LocalizationTests.self)
        XCTAssertEqual(L10n.tr("Status: disconnecting in %lds", 7), "Status: disconnecting in 7s")
    }
}
