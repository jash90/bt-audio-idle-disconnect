import AppKit
import CryptoKit
import Foundation

/// Dotted numeric version ("1.10.0"). Missing components count as zero, so "1.1" == "1.1.0";
/// a leading "v" and any "-beta" / "+build" suffix are ignored.
struct SemanticVersion: Comparable, CustomStringConvertible {
    let components: [Int]

    init?(_ string: String) {
        var s = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if s.first == "v" || s.first == "V" { s = s.dropFirst() }
        if let cut = s.firstIndex(where: { $0 == "-" || $0 == "+" }) { s = s[..<cut] }
        var comps: [Int] = []
        for part in s.split(separator: ".", omittingEmptySubsequences: false) {
            guard let n = Int(part), n >= 0 else { return nil }
            comps.append(n)
        }
        guard !comps.isEmpty else { return nil }
        components = comps
    }

    var description: String { components.map(String.init).joined(separator: ".") }

    private static func padded(_ a: SemanticVersion, _ b: SemanticVersion) -> ([Int], [Int]) {
        let n = max(a.components.count, b.components.count)
        return (a.components + Array(repeating: 0, count: n - a.components.count),
                b.components + Array(repeating: 0, count: n - b.components.count))
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let (a, b) = padded(lhs, rhs)
        return a == b
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let (a, b) = padded(lhs, rhs)
        return a.lexicographicallyPrecedes(b)
    }
}

/// The subset of GitHub's `releases/latest` payload the updater needs.
struct Release: Decodable, Equatable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL
        let size: Int
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }

        /// Lowercase hex from GitHub's `"sha256:<hex>"` digest, nil if absent or malformed.
        var sha256: String? {
            guard let d = digest?.lowercased(), d.hasPrefix("sha256:") else { return nil }
            let hex = String(d.dropFirst("sha256:".count))
            return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? hex : nil
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }

    var version: SemanticVersion? { SemanticVersion(tagName) }
    var displayVersion: String { version?.description ?? tagName }
    var dmgAsset: Asset? { assets.first { $0.name.lowercased().hasSuffix(".dmg") } }
}

enum UpdateError: LocalizedError, Equatable {
    case network(String)
    case rateLimited
    case noRelease
    case badResponse(Int)
    case invalidData
    case noInstaller
    case noChecksum
    case checksumMismatch
    case notPackaged
    case invalidBundle(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .network(let m): return "Couldn't reach GitHub: \(m)"
        case .rateLimited: return "GitHub is rate-limiting update checks. Try again later."
        case .noRelease: return "No published release was found."
        case .badResponse(let code): return "GitHub answered with HTTP \(code)."
        case .invalidData: return "GitHub sent a response the app couldn't read."
        case .noInstaller: return "This release has no .dmg to install."
        case .noChecksum: return "This release has no SHA-256 checksum, so it won't be installed automatically."
        case .checksumMismatch: return "The download didn't match its SHA-256 checksum and was discarded."
        case .notPackaged: return "Updates can only be installed into the packaged .app."
        case .invalidBundle(let m): return "The downloaded app failed verification: \(m)"
        case .commandFailed(let m): return "Installing failed: \(m)"
        }
    }
}

/// Checks GitHub Releases for a newer version, downloads its DMG, verifies it and swaps the
/// running .app via a detached shell script that waits for this process to exit.
final class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(progress: Double)
        case installing
        /// The new app was verified but the current folder isn't writable; the DMG was opened instead.
        case manualInstallRequired
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/jash90/bt-audio-idle-disconnect/releases/latest")!
    static let checkInterval: TimeInterval = 24 * 60 * 60

    static var currentVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var currentBuildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private let settings = SettingsStore.shared
    private let workQueue = DispatchQueue(label: "btaid.updater")
    private var autoCheckTimer: Timer?
    private var checkInFlight = false
    private var downloadSession: URLSession?
    private var downloadingRelease: Release?

    private var updatesDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BTAudioIdleDisconnect/Updates", isDirectory: true)
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return checkInFlight
        }
    }

    private override init() {
        super.init()
    }

    // MARK: - Automatic checks

    func startAutomaticChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self else { return }
            self.automaticCheckIfDue()
            let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
                self?.automaticCheckIfDue()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.autoCheckTimer = timer
        }
    }

    private func automaticCheckIfDue() {
        let s = settings.settings
        guard s.autoCheckForUpdates, !isBusy else { return }
        if case .available = state { return }
        if let last = s.lastUpdateCheck, Date().timeIntervalSince(last) < Self.checkInterval { return }
        check(userInitiated: false)
    }

    // MARK: - Checking

    /// Background checks never surface errors in the UI — they only log them.
    func check(userInitiated: Bool) {
        guard !isBusy else { return }
        checkInFlight = true
        if userInitiated { state = .checking }
        AppLogger.info("Update check started (userInitiated=\(userInitiated), current=\(Self.currentVersionString))")

        var request = URLRequest(url: Self.latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BTAudioIdle/\(Self.currentVersionString)", forHTTPHeaderField: "User-Agent")

        let current = SemanticVersion(Self.currentVersionString) ?? SemanticVersion("0")!
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let result = Self.evaluate(
                data: data,
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                error: error,
                current: current
            )
            DispatchQueue.main.async { self?.finishCheck(result, userInitiated: userInitiated) }
        }.resume()
    }

    /// Pure response handling: `.success(release)` when it is newer than `current`,
    /// `.success(nil)` when already up to date.
    static func evaluate(data: Data?, statusCode: Int?, error: Error?, current: SemanticVersion) -> Result<Release?, UpdateError> {
        if let error { return .failure(.network(error.localizedDescription)) }
        switch statusCode ?? 0 {
        case 200: break
        case 403, 429: return .failure(.rateLimited)
        case 404: return .failure(.noRelease)
        case let code: return .failure(.badResponse(code))
        }
        guard let data, let release = try? JSONDecoder().decode(Release.self, from: data),
              let version = release.version else {
            return .failure(.invalidData)
        }
        return .success(version > current ? release : nil)
    }

    private func finishCheck(_ result: Result<Release?, UpdateError>, userInitiated: Bool) {
        checkInFlight = false
        switch result {
        case .success(let release):
            settings.settings.lastUpdateCheck = Date()
            if let release {
                AppLogger.info("Update available: \(release.displayVersion) (dmg=\(release.dmgAsset?.name ?? "none"))")
                state = .available(release)
                if !userInitiated, settings.settings.lastNotifiedUpdateVersion != release.displayVersion {
                    settings.settings.lastNotifiedUpdateVersion = release.displayVersion
                    NotificationManager.shared.sendUpdateAvailable(version: release.displayVersion)
                }
            } else {
                AppLogger.info("Update check: up to date")
                state = userInitiated ? .upToDate : .idle
            }
        case .failure(let error):
            AppLogger.warn("Update check failed: \(error.localizedDescription)")
            if userInitiated { state = .failed(error.localizedDescription) }
        }
    }

    // MARK: - Download

    func downloadAndInstall() {
        guard case .available(let release) = state else { return }
        guard let asset = release.dmgAsset else { return fail(.noInstaller) }
        guard asset.sha256 != nil else { return fail(.noChecksum) }

        try? FileManager.default.removeItem(at: updatesDir)
        do {
            try FileManager.default.createDirectory(at: updatesDir, withIntermediateDirectories: true)
        } catch {
            return fail(.commandFailed("can't create \(updatesDir.path): \(error.localizedDescription)"))
        }

        AppLogger.info("Downloading update \(release.displayVersion) from \(asset.browserDownloadURL)")
        state = .downloading(progress: 0)
        downloadingRelease = release
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
        downloadSession = session
        session.downloadTask(with: asset.browserDownloadURL).resume()
    }

    private func fail(_ error: UpdateError) {
        AppLogger.error("Update failed: \(error.localizedDescription)")
        downloadingRelease = nil
        state = .failed(error.localizedDescription)
    }

    // MARK: - Install

    private func install(dmg: URL, release: Release) {
        workQueue.async { [self] in
            do {
                guard let expected = release.dmgAsset?.sha256 else { throw UpdateError.noChecksum }
                guard try Self.sha256Hex(of: dmg) == expected else {
                    try? FileManager.default.removeItem(at: dmg)
                    throw UpdateError.checksumMismatch
                }
                AppLogger.info("Update SHA-256 verified (\(expected))")

                let target = Bundle.main.bundleURL
                guard target.pathExtension == "app", Bundle.main.bundleIdentifier != nil else {
                    throw UpdateError.notPackaged
                }

                let staged = try stage(dmg: dmg, release: release, appName: target.lastPathComponent)

                let fm = FileManager.default
                guard fm.isWritableFile(atPath: target.deletingLastPathComponent().path),
                      fm.isWritableFile(atPath: target.path) else {
                    AppLogger.warn("Can't write to \(target.deletingLastPathComponent().path) — opening the DMG for a manual install")
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(dmg)
                        self.downloadingRelease = nil
                        self.state = .manualInstallRequired
                    }
                    return
                }

                try launchInstaller(target: target, staged: staged)
                DispatchQueue.main.async {
                    self.state = .installing
                    AppLogger.info("Update \(release.displayVersion) staged — quitting so the installer can swap the app")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
                }
            } catch {
                let updateError = error as? UpdateError ?? .commandFailed(error.localizedDescription)
                DispatchQueue.main.async { self.fail(updateError) }
            }
        }
    }

    /// Mounts the DMG, verifies the .app inside and copies it out. Returns the staged copy.
    private func stage(dmg: URL, release: Release, appName: String) throws -> URL {
        let fm = FileManager.default
        let mountPoint = updatesDir.appendingPathComponent("mount-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: mountPoint) }

        try Self.run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path])
        defer {
            do { try Self.run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }
            catch { AppLogger.warn("hdiutil detach failed: \(error.localizedDescription)") }
        }
        AppLogger.info("Update DMG mounted at \(mountPoint.path)")

        let contents = try fm.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.invalidBundle("no .app in the disk image")
        }

        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        let bundleId = info?["CFBundleIdentifier"] as? String
        guard bundleId == Bundle.main.bundleIdentifier else {
            throw UpdateError.invalidBundle("bundle id \(bundleId ?? "missing") ≠ \(Bundle.main.bundleIdentifier ?? "?")")
        }
        let appVersion = (info?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
        guard let appVersion, let expected = release.version, appVersion == expected else {
            throw UpdateError.invalidBundle("app version \(appVersion?.description ?? "missing") ≠ release \(release.displayVersion)")
        }
        do {
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        } catch {
            throw UpdateError.invalidBundle("code signature is invalid")
        }

        let stagedDir = updatesDir.appendingPathComponent("staged", isDirectory: true)
        try? fm.removeItem(at: stagedDir)
        try fm.createDirectory(at: stagedDir, withIntermediateDirectories: true)
        let staged = stagedDir.appendingPathComponent(appName)
        try Self.run("/usr/bin/ditto", [app.path, staged.path])
        return staged
    }

    /// Starts a shell script that outlives this process: it waits for our PID to exit, swaps
    /// the bundle (restoring the old one if the copy fails) and relaunches the app.
    private func launchInstaller(target: URL, staged: URL) throws {
        let script = updatesDir.appendingPathComponent("install.sh")
        try Self.installScript.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            script.path,
            String(ProcessInfo.processInfo.processIdentifier),
            target.path,
            staged.path,
            AppLogger.shared.logFileURL.path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static let installScript = """
    #!/bin/sh
    PID="$1"; TARGET="$2"; STAGED="$3"; LOG="$4"
    log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [INFO] installer: $1" >> "$LOG"; }

    i=0
    while kill -0 "$PID" 2>/dev/null; do
      i=$((i + 1))
      if [ "$i" -gt 300 ]; then log "app did not quit within 30s, aborting"; exit 1; fi
      sleep 0.1
    done

    NEW="$TARGET.new"; OLD="$TARGET.old"
    rm -rf "$NEW" "$OLD"
    if ! ditto "$STAGED" "$NEW"; then
      log "copy failed, keeping the current version"; rm -rf "$NEW"; open "$TARGET"; exit 1
    fi
    xattr -dr com.apple.quarantine "$NEW" 2>/dev/null
    if mv "$TARGET" "$OLD" && mv "$NEW" "$TARGET"; then
      rm -rf "$OLD"
      log "installed update into $TARGET"
    else
      log "swap failed, restoring the previous version"
      [ -d "$OLD" ] && [ ! -d "$TARGET" ] && mv "$OLD" "$TARGET"
      rm -rf "$NEW"
    fi
    rm -rf "$STAGED"
    open "$TARGET"
    """

    // MARK: - Helpers

    static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    static func run(_ tool: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            let name = (tool as NSString).lastPathComponent
            throw UpdateError.commandFailed("\(name) exited \(process.terminationStatus): \(output.prefix(200))")
        }
        return output
    }
}

extension UpdateChecker: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : Int64(downloadingRelease?.dmgAsset?.size ?? 0)
        guard expected > 0 else { return }
        state = .downloading(progress: min(1, Double(totalBytesWritten) / Double(expected)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let release = downloadingRelease, let asset = release.dmgAsset else { return }
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            downloadingRelease = nil
            return fail(.badResponse(status))
        }
        // The temporary file is deleted as soon as this method returns, so move it now.
        let dmg = updatesDir.appendingPathComponent(asset.name)
        do {
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: location, to: dmg)
        } catch {
            return fail(.commandFailed("can't save the download: \(error.localizedDescription)"))
        }
        AppLogger.info("Update downloaded to \(dmg.path)")
        state = .downloading(progress: 1)
        install(dmg: dmg, release: release)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        session.finishTasksAndInvalidate()
        downloadSession = nil
        if let error, downloadingRelease != nil {
            fail(.network(error.localizedDescription))
        }
    }
}
