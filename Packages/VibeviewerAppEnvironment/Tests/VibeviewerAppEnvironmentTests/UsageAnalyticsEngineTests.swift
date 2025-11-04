import XCTest
import VibeviewerCore
import VibeviewerModel
@testable import VibeviewerAppEnvironment

final class UsageAnalyticsEngineTests: XCTestCase {
    func testAggregationProducesPresets() {
        let now = Date()
        let events = (0..<6).map { index -> UsageEvent in
            let date = now.addingTimeInterval(Double(-index) * 3_600)
            return UsageEvent(
                occurredAtMs: VibeviewerCore.DateUtils.millisecondsString(from: date),
                modelName: "gpt-4",
                kind: "completion",
                requestCostCount: 1,
                usageCostDisplay: "$0.01",
                usageCostCents: 1,
                isTokenBased: true,
                userDisplayName: "user"
            )
        }
        let totals = [ProviderUsageTotal(provider: .cursor, spendCents: 6, requestCount: 6)]
        let settings = AppSettings()
        let engine = UsageAnalyticsEngine()
        let result = engine.evaluate(events: events, providerTotals: totals, settings: settings, existingSnapshot: nil)
        XCTAssertEqual(result.aggregations.count, UsageAggregationPreset.allCases.count)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertNotNil(result.liveMetrics)
    }
}
