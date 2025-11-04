import Foundation
import VibeviewerModel

public struct UsageAnalyticsResult: Sendable {
    public let aggregations: [UsageAggregationMetric]
    public let warnings: [ForecastWarning]
    public let liveMetrics: LiveUsageMetrics?
    public let personalization: PersonalizationProfile
    public let developerExport: DeveloperExport

    public init(
        aggregations: [UsageAggregationMetric],
        warnings: [ForecastWarning],
        liveMetrics: LiveUsageMetrics?,
        personalization: PersonalizationProfile,
        developerExport: DeveloperExport
    ) {
        self.aggregations = aggregations
        self.warnings = warnings
        self.liveMetrics = liveMetrics
        self.personalization = personalization
        self.developerExport = developerExport
    }
}

public struct UsageAnalyticsEngine: Sendable {
    public init() {}

    public func evaluate(
        events: [UsageEvent],
        providerTotals: [ProviderUsageTotal],
        settings: AppSettings,
        existingSnapshot: DashboardSnapshot?
    ) -> UsageAnalyticsResult {
        let personalization = buildPersonalization(settings: settings, snapshot: existingSnapshot)
        let aggregations = buildAggregations(events: events, providerTotals: providerTotals, personalization: personalization)
        let warnings = buildForecasts(events: events, personalization: personalization, settings: settings)
        let liveMetrics = buildLiveMetrics(events: events)
        let export = buildDeveloperExport(
            aggregations: aggregations,
            liveMetrics: liveMetrics,
            warnings: warnings,
            settings: settings,
            personalization: personalization
        )
        return UsageAnalyticsResult(
            aggregations: aggregations,
            warnings: warnings,
            liveMetrics: liveMetrics,
            personalization: personalization,
            developerExport: export
        )
    }

    private func buildPersonalization(settings: AppSettings, snapshot: DashboardSnapshot?) -> PersonalizationProfile {
        if settings.advanced.autoDetectPreferences {
            let locale = Locale.autoupdatingCurrent
            let tz = TimeZone.autoupdatingCurrent
            let currency = locale.currency?.identifier ?? "USD"
            let inferredPlan = snapshot?.usageSummary?.individualUsage.plan.limit > 0 ? "Paid" : nil
            return PersonalizationProfile(
                localeIdentifier: locale.identifier,
                timezoneIdentifier: tz.identifier,
                currencyCode: currency,
                appearance: settings.appearance,
                inferredPlan: inferredPlan
            )
        }
        return PersonalizationProfile(
            localeIdentifier: settings.providerSettings.openAIOrganization ?? Locale.current.identifier,
            timezoneIdentifier: TimeZone.current.identifier,
            currencyCode: "USD",
            appearance: settings.appearance,
            inferredPlan: nil
        )
    }

    private func buildAggregations(
        events: [UsageEvent],
        providerTotals: [ProviderUsageTotal],
        personalization: PersonalizationProfile
    ) -> [UsageAggregationMetric] {
        guard !events.isEmpty else {
            let providerRows = providerTotals.map { total in
                UsageAggregationRow(
                    preset: .providerTotals,
                    startDate: Date(),
                    endDate: Date(),
                    requestCount: total.requestCount,
                    spendCents: total.spendCents,
                    providerIdentifier: total.provider.rawValue
                )
            }
            return providerRows.isEmpty ? [] : [UsageAggregationMetric(preset: .providerTotals, rows: providerRows)]
        }

        var metrics: [UsageAggregationMetric] = []
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: personalization.timezoneIdentifier) ?? .current
        var cal = calendar
        cal.timeZone = tz

        let sorted = events.sorted { lhs, rhs in
            guard let lDate = DateUtils.date(fromMillisecondsString: lhs.occurredAtMs),
                  let rDate = DateUtils.date(fromMillisecondsString: rhs.occurredAtMs) else { return false }
            return lDate > rDate
        }

        func aggregate(by component: Calendar.Component, spanHours: Int? = nil) -> UsageAggregationMetric {
            var buckets: [Date: (Int, Int)] = [:]
            for event in sorted {
                guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
                let key: Date
                if let spanHours {
                    let comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
                    let adjustedHour = (comps.hour ?? 0) / spanHours * spanHours
                    key = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: adjustedHour)) ?? date
                } else {
                    key = cal.dateInterval(of: component, for: date)?.start ?? date
                }
                var entry = buckets[key] ?? (0, 0)
                entry.0 += event.requestCostCount
                entry.1 += event.usageCostCents
                buckets[key] = entry
            }
            let rows = buckets.keys.sorted(by: { $0 < $1 }).map { start -> UsageAggregationRow in
                let end: Date
                if let spanHours {
                    end = cal.date(byAdding: .hour, value: spanHours, to: start) ?? start
                } else if let interval = cal.dateInterval(of: component, for: start) {
                    end = interval.end
                } else {
                    end = start
                }
                let values = buckets[start] ?? (0, 0)
                return UsageAggregationRow(
                    preset: componentPreset(component: component, spanHours: spanHours),
                    startDate: start,
                    endDate: end,
                    requestCount: values.0,
                    spendCents: values.1
                )
            }
            return UsageAggregationMetric(
                preset: componentPreset(component: component, spanHours: spanHours),
                rows: rows
            )
        }

        metrics.append(aggregate(by: .hour, spanHours: 5))
        metrics.append(aggregate(by: .day))
        metrics.append(aggregate(by: .weekOfYear))
        metrics.append(aggregate(by: .month))

        let sessionRows = buildSessionRows(events: sorted, calendar: cal)
        metrics.append(UsageAggregationMetric(preset: .sessions, rows: sessionRows))

        if !providerTotals.isEmpty {
            let providerRows = providerTotals.map { total in
                UsageAggregationRow(
                    preset: .providerTotals,
                    startDate: Date(),
                    endDate: Date(),
                    requestCount: total.requestCount,
                    spendCents: total.spendCents,
                    providerIdentifier: total.provider.rawValue
                )
            }
            metrics.append(UsageAggregationMetric(preset: .providerTotals, rows: providerRows))
        }

        return metrics
    }

    private func componentPreset(component: Calendar.Component, spanHours: Int?) -> UsageAggregationPreset {
        if let spanHours, spanHours == 5 { return .fiveHourBlocks }
        switch component {
        case .day: return .daily
        case .weekOfYear: return .weekly
        case .month: return .monthly
        default: return .daily
        }
    }

    private func buildSessionRows(events: [UsageEvent], calendar: Calendar) -> [UsageAggregationRow] {
        guard !events.isEmpty else { return [] }
        var rows: [UsageAggregationRow] = []
        var currentStart: Date?
        var currentEnd: Date?
        var requestCount = 0
        var spend = 0
        let sessionGap: TimeInterval = 30 * 60

        for event in events.sorted(by: { $0.occurredAtMs < $1.occurredAtMs }) {
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
            if let end = currentEnd, date.timeIntervalSince(end) > sessionGap {
                if let start = currentStart, let endDate = currentEnd {
                    rows.append(
                        UsageAggregationRow(
                            preset: .sessions,
                            startDate: start,
                            endDate: endDate,
                            requestCount: requestCount,
                            spendCents: spend
                        )
                    )
                }
                currentStart = date
                currentEnd = date
                requestCount = event.requestCostCount
                spend = event.usageCostCents
            } else {
                currentStart = currentStart ?? date
                currentEnd = date
                requestCount += event.requestCostCount
                spend += event.usageCostCents
            }
        }

        if let start = currentStart, let end = currentEnd {
            rows.append(
                UsageAggregationRow(
                    preset: .sessions,
                    startDate: start,
                    endDate: end,
                    requestCount: requestCount,
                    spendCents: spend
                )
            )
        }
        return rows
    }

    private func buildForecasts(
        events: [UsageEvent],
        personalization: PersonalizationProfile,
        settings: AppSettings
    ) -> [ForecastWarning] {
        guard !events.isEmpty else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = TimeZone(identifier: personalization.timezoneIdentifier) ?? .current
        var dailySpend: [Date: Int] = [:]
        for event in events {
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
            let start = cal.startOfDay(for: date)
            dailySpend[start, default: 0] += event.usageCostCents
        }
        let values = dailySpend.values.sorted()
        guard !values.isEmpty else { return [] }
        let percentileIndex = Int(Double(values.count - 1) * 0.9)
        let p90 = values[min(max(percentileIndex, 0), values.count - 1)]
        let burnRate = Double(p90) / 24.0
        let projected = Int(burnRate * 24.0 * 30.0)
        let threshold = Int(Double(settings.overview.refreshInterval) * settings.advanced.notificationThresholdPercent * 100)
        let severity: ForecastSeverity
        if projected >= threshold * 2 {
            severity = .critical
        } else if projected >= threshold {
            severity = .warning
        } else {
            severity = .info
        }
        let message = "Projected monthly spend \((Double(projected) / 100.0).formatted(.currency(code: personalization.currencyCode)))"
        return [
            ForecastWarning(
                preset: .monthly,
                projectedAt: Date(),
                message: message,
                severity: severity,
                projectedValueCents: projected,
                thresholdCents: threshold
            )
        ]
    }

    private func buildLiveMetrics(events: [UsageEvent]) -> LiveUsageMetrics? {
        guard !events.isEmpty else { return nil }
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let recent = events.compactMap { event -> (Date, UsageEvent)? in
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { return nil }
            return (date, event)
        }.filter { $0.0 >= hourAgo }
        guard !recent.isEmpty else {
            return LiveUsageMetrics(lastUpdated: now, burnRateCentsPerHour: 0, activeEvents: [], sparklinePoints: [])
        }
        let burn = recent.reduce(0) { $0 + $1.1.usageCostCents }
        let sorted = recent.sorted(by: { $0.0 < $1.0 })
        let points = sorted.map { Double($0.1.usageCostCents) / 100.0 }
        return LiveUsageMetrics(
            lastUpdated: now,
            burnRateCentsPerHour: Double(burn),
            activeEvents: sorted.map { $0.1 },
            sparklinePoints: points
        )
    }

    private func buildDeveloperExport(
        aggregations: [UsageAggregationMetric],
        liveMetrics: LiveUsageMetrics?,
        warnings: [ForecastWarning],
        settings: AppSettings,
        personalization: PersonalizationProfile
    ) -> DeveloperExport {
        let latestSpend = aggregations.first { $0.preset == .daily }?.rows.last?.spendCents ?? 0
        let warningText = warnings.first?.message ?? "Stable"
        let statusLine = "Spend: \((Double(latestSpend) / 100.0).formatted(.currency(code: personalization.currencyCode))) | Status: \(warningText)"
        let exportPath = (settings.advanced.statusExportPath as NSString).expandingTildeInPath
        return DeveloperExport(statusLine: statusLine, exportPath: exportPath, lastWritten: Date())
    }
}
