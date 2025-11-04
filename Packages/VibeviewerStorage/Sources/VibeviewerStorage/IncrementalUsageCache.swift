import Foundation
import VibeviewerModel
import VibeviewerCore

public actor IncrementalUsageCache {
    public static let shared = IncrementalUsageCache()

    private let storageURL: URL
    private var state: CacheState

    public struct CacheState: Codable {
        public var watermark: String?
        public var events: [UsageEvent]

        public init(watermark: String? = nil, events: [UsageEvent] = []) {
            self.watermark = watermark
            self.events = events
        }
    }

    public init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = support.appendingPathComponent("AIUsageTracker", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.storageURL = directory.appendingPathComponent("usage-cache.json")
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(CacheState.self, from: data) {
            self.state = decoded
        } else {
            self.state = CacheState()
        }
    }

    public func loadEvents() -> [UsageEvent] {
        state.events
    }

    public func currentWatermark() -> String? {
        state.watermark
    }

    @discardableResult
    public func append(newEvents: [UsageEvent], retentionDays: Int) async throws -> [UsageEvent] {
        guard !newEvents.isEmpty else { return state.events }
        let merged = (newEvents + state.events)
            .sorted { lhs, rhs in lhs.occurredAtMs > rhs.occurredAtMs }
        let retentionInterval = TimeInterval(retentionDays * 24 * 60 * 60)
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let filtered = merged.filter { event in
            guard let date = VibeviewerCore.DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { return false }
            return date >= cutoff
        }
        state.events = filtered
        state.watermark = newEvents.first?.occurredAtMs ?? state.watermark
        try persist()
        return state.events
    }

    public func overwrite(events: [UsageEvent], watermark: String?) async throws {
        state.events = events
        state.watermark = watermark
        try persist()
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(state)
        try data.write(to: storageURL, options: [.atomic])
    }
}
