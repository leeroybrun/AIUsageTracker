import Foundation

public enum UsageAggregationPreset: String, Codable, Sendable, CaseIterable, Equatable, Identifiable {
    case fiveHourBlocks
    case daily
    case weekly
    case monthly
    case sessions
    case providerTotals

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .fiveHourBlocks:
            return "5-Hour Blocks"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .sessions:
            return "Sessions"
        case .providerTotals:
            return "Providers"
        }
    }
}

public struct UsageAggregationRow: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var preset: UsageAggregationPreset
    public var startDate: Date
    public var endDate: Date
    public var requestCount: Int
    public var spendCents: Int
    public var providerIdentifier: String?

    public init(
        id: UUID = UUID(),
        preset: UsageAggregationPreset,
        startDate: Date,
        endDate: Date,
        requestCount: Int,
        spendCents: Int,
        providerIdentifier: String? = nil
    ) {
        self.id = id
        self.preset = preset
        self.startDate = startDate
        self.endDate = endDate
        self.requestCount = requestCount
        self.spendCents = spendCents
        self.providerIdentifier = providerIdentifier
    }
}

public struct UsageAggregationMetric: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var preset: UsageAggregationPreset
    public var rows: [UsageAggregationRow]

    public init(id: UUID = UUID(), preset: UsageAggregationPreset, rows: [UsageAggregationRow]) {
        self.id = id
        self.preset = preset
        self.rows = rows
    }
}

public enum ForecastSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public struct ForecastWarning: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var preset: UsageAggregationPreset
    public var projectedAt: Date
    public var message: String
    public var severity: ForecastSeverity
    public var projectedValueCents: Int
    public var thresholdCents: Int

    public init(
        id: UUID = UUID(),
        preset: UsageAggregationPreset,
        projectedAt: Date,
        message: String,
        severity: ForecastSeverity,
        projectedValueCents: Int,
        thresholdCents: Int
    ) {
        self.id = id
        self.preset = preset
        self.projectedAt = projectedAt
        self.message = message
        self.severity = severity
        self.projectedValueCents = projectedValueCents
        self.thresholdCents = thresholdCents
    }
}

public struct PersonalizationProfile: Codable, Sendable, Equatable {
    public var localeIdentifier: String
    public var timezoneIdentifier: String
    public var currencyCode: String
    public var appearance: AppAppearance
    public var inferredPlan: String?

    public init(
        localeIdentifier: String,
        timezoneIdentifier: String,
        currencyCode: String,
        appearance: AppAppearance,
        inferredPlan: String? = nil
    ) {
        self.localeIdentifier = localeIdentifier
        self.timezoneIdentifier = timezoneIdentifier
        self.currencyCode = currencyCode
        self.appearance = appearance
        self.inferredPlan = inferredPlan
    }
}

public struct LiveUsageMetrics: Codable, Sendable, Equatable {
    public var lastUpdated: Date
    public var burnRateCentsPerHour: Double
    public var activeEvents: [UsageEvent]
    public var sparklinePoints: [Double]

    public init(lastUpdated: Date, burnRateCentsPerHour: Double, activeEvents: [UsageEvent], sparklinePoints: [Double]) {
        self.lastUpdated = lastUpdated
        self.burnRateCentsPerHour = burnRateCentsPerHour
        self.activeEvents = activeEvents
        self.sparklinePoints = sparklinePoints
    }
}

public struct DeveloperExport: Codable, Sendable, Equatable {
    public var statusLine: String
    public var exportPath: String
    public var lastWritten: Date

    public init(statusLine: String, exportPath: String, lastWritten: Date) {
        self.statusLine = statusLine
        self.exportPath = exportPath
        self.lastWritten = lastWritten
    }
}
