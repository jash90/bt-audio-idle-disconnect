import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

final class AppLogger {
    static let shared = AppLogger()

    let logFileURL: URL

    private let queue = DispatchQueue(label: "btaid.logger")
    private let dateFormatter: ISO8601DateFormatter
    private let maxBytes: Int = 1_000_000

    private init() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("BTAudioIdleDisconnect.log")

        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = f
    }

    func log(_ level: LogLevel, _ message: String) {
        let line = "\(dateFormatter.string(from: Date())) [\(level.rawValue)] \(message)\n"
        queue.async { [self] in
            FileHandle.standardError.write(Data(line.utf8))
            rotateIfNeeded()
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logFileURL.path),
               let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    private func rotateIfNeeded() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
        let size = (attrs?[.size] as? Int) ?? 0
        guard size > maxBytes else { return }
        let backup = logFileURL.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: logFileURL, to: backup)
    }

    static func debug(_ m: String) { shared.log(.debug, m) }
    static func info(_ m: String)  { shared.log(.info, m) }
    static func warn(_ m: String)  { shared.log(.warn, m) }
    static func error(_ m: String) { shared.log(.error, m) }
}
