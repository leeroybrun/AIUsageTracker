import Foundation

public actor DiagnosticsLogger {
    public static let shared = DiagnosticsLogger()
    private let logURL: URL
    private let maxSize: Int = 1_000_000

    public init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = support.appendingPathComponent("AIUsageTracker", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.logURL = directory.appendingPathComponent("diagnostics.log")
    }

    public func log(_ message: String) {
        let entry = "[\(Date())] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
            rotateIfNeeded()
        }
    }

    public func exportURL() -> URL { logURL }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = attributes[.size] as? NSNumber else { return }
        if size.intValue > maxSize {
            let archivedURL = logURL.deletingLastPathComponent().appendingPathComponent("diagnostics-\(Int(Date().timeIntervalSince1970)).log")
            try? FileManager.default.moveItem(at: logURL, to: archivedURL)
        }
    }
}
