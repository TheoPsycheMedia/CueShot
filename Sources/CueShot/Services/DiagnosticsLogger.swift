import Foundation

struct DiagnosticsLogger {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func record(_ message: String) {
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let line = "\(formatter.string(from: .now)) \(message)\n"
            if fileManager.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Diagnostics must never interrupt capture.
        }
    }

    private var logDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CueShot", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    var logURL: URL {
        logDirectory.appendingPathComponent("events.log")
    }

}
