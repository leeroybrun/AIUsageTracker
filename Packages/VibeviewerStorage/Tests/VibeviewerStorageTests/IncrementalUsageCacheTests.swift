import XCTest
import VibeviewerStorage
import VibeviewerModel
import VibeviewerCore

final class IncrementalUsageCacheTests: XCTestCase {
    func testAppendRespectsRetention() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let manager = TestingFileManager(baseURL: tempDir)
        let cache = IncrementalUsageCache(fileManager: manager)
        let now = Date()
        let events = (0..<3).map { index -> UsageEvent in
            let date = now.addingTimeInterval(Double(-index) * 86_400)
            return UsageEvent(
                occurredAtMs: DateUtils.millisecondsString(from: date),
                modelName: "gpt-4",
                kind: "completion",
                requestCostCount: 1,
                usageCostDisplay: "$0.01",
                usageCostCents: 1,
                isTokenBased: true,
                userDisplayName: "user"
            )
        }
        let merged = try await cache.append(newEvents: events, retentionDays: 2)
        XCTAssertLessThanOrEqual(merged.count, 2)
    }
}

private final class TestingFileManager: FileManager {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        super.init()
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        [baseURL]
    }
}
