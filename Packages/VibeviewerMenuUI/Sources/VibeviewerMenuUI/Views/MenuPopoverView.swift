import Observation
import SwiftUI
import VibeviewerAPI
import VibeviewerAppEnvironment
import VibeviewerLoginUI
import VibeviewerModel
import VibeviewerSettingsUI
import VibeviewerCore
import VibeviewerShareUI

@MainActor
public struct MenuPopoverView: View {
    @Environment(\.cursorService) private var service
    @Environment(\.cursorStorage) private var storage
    @Environment(\.loginWindowManager) private var loginWindow
    @Environment(\.settingsWindowManager) private var settingsWindow
    @Environment(\.dashboardRefreshService) private var refresher
    @Environment(AppSettings.self) private var appSettings
    @Environment(AppSession.self) private var session

    @Environment(\.colorScheme) private var colorScheme

    enum ViewState: Equatable {
        case loading
        case loaded
        case error(String)
    }

    public init() {}

    @State private var state: ViewState = .loading
    @State private var showLiveMonitoring: Bool = false

    public var body: some View {
        @Bindable var appSettings = appSettings

        VStack(alignment: .leading, spacing: 16) {
            UsageHeaderView { action in
                switch action {
                case .dashboard:
                    self.openDashboard()
                case .logout:
                    Task {
                        await self.setLoggedOut()
                    }
                }
            }

            if let snapshot = self.session.snapshot {
                if !snapshot.forecastWarnings.isEmpty {
                    AlertsView(warnings: snapshot.forecastWarnings)
                    Divider().opacity(0.5)
                }

                MetricsView(metric: .billing(snapshot.billingMetrics))

                if let free = snapshot.freeUsageMetrics {
                    MetricsView(metric: .free(free))
                }

                if let onDemandMetrics = snapshot.onDemandMetrics {
                    MetricsView(metric: .onDemand(onDemandMetrics))
                }

                Divider().opacity(0.5)

                Toggle(isOn: $showLiveMonitoring) {
                    Text(LocalizedStringResource("live.toggle", bundle: .module, table: "Menu"))
                        .font(.app(.satoshiMedium, size: 12))
                }
                .toggleStyle(.switch)

                if showLiveMonitoring, let live = snapshot.liveMetrics {
                    LiveUsageSection(metrics: live)
                } else {
                    UsageEventView(events: self.session.snapshot?.usageEvents ?? [])
                }

                if let analytics = self.session.snapshot?.userAnalytics {
                    Divider().opacity(0.5)

                    UserAnalyticsChartView(analytics: analytics)
                }

                Divider().opacity(0.5)

                totalCreditsUsageView

                if !snapshot.aggregations.isEmpty {
                    Divider().opacity(0.5)
                    AggregationsSection(aggregations: snapshot.aggregations)
                }

                if let totals = self.session.snapshot?.providerTotals, !totals.isEmpty {
                    Divider().opacity(0.5)
                    providerTotalsView(totals: totals)
                }

                Divider().opacity(0.5)

                MenuFooterView()
            } else {
                loginButtonView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background {
            ZStack {
                Color(hex: colorScheme == .dark ? "1F1E1E" : "F9F9F9")
                Circle()
                    .fill(Color(hex: colorScheme == .dark ? "354E48" : "F2A48B"))
                    .padding(80)
                    .blur(radius: 100)
            }
            .cornerRadiusWithCorners(32 - 4)
        }
        .padding(session.credentials != nil ? 4 : 0)
    }

    private var loginButtonView: some View {
        Button {
            loginWindow.show(onCookieCaptured: { cookie in
                Task {
                    guard let me = try? await self.service.fetchMe(cookieHeader: cookie) else { return }
                    try? await self.storage.saveCredentials(me)
                    await self.refresher.start()
                    self.session.credentials = me
                    self.session.snapshot = await self.storage.loadDashboardSnapshot()
                }
            })
        } label: {
            Text(LocalizedStringResource("login.button", bundle: .module, table: "Menu"))
        }
        .buttonStyle(.vibe(.primary))
        .maxFrame(true, false)
    }

    private var totalCreditsUsageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringResource("usage.total", bundle: .module, table: "Menu"))
                .font(.app(.satoshiRegular, size: 12))
                .foregroundStyle(.secondary)

            Text(session.snapshot?.totalUsageCents.dollarStringFromCents ?? "0")
                .font(.app(.satoshiBold, size: 16))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            if let localized = session.snapshot?.localizedSpendDisplay {
                Text(localized)
                    .font(.app(.satoshiMedium, size: 11))
                    .foregroundStyle(.secondary)
            }

        }
        .maxFrame(true, false, alignment: .leading)
    }

    private func providerTotalsView(totals: [ProviderUsageTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringResource("providers.title", bundle: .module, table: "Menu"))
                .font(.app(.satoshiRegular, size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(totals) { total in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(total.provider.displayName)
                                .font(.app(.satoshiMedium, size: 13))
                                .foregroundStyle(.primary)
                            Text("Requests: \(total.requestCount)")
                                .font(.app(.satoshiRegular, size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(self.formattedSpend(for: total))
                            .font(.app(.satoshiBold, size: 13))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(10)
        }
        .maxFrame(true, false, alignment: .leading)
    }

    private func formattedSpend(for total: ProviderUsageTotal) -> String {
        if total.currencyCode.uppercased() == "USD" {
            return total.spendCents.dollarStringFromCents
        }
        let amount = Double(total.spendCents) / 100.0
        return String(format: "%@ %.2f", total.currencyCode.uppercased(), amount)
    }
    
    private func setLoggedOut() async {
        await self.storage.clearCredentials()
        await self.storage.clearDashboardSnapshot()
        self.session.credentials = nil
        self.session.snapshot = nil
    }

    private func openDashboard() {
        NSWorkspace.shared.open(URL(string: "https://cursor.com/dashboard?tab=usage")!)
    }
}

private struct AlertsView: View {
    let warnings: [ForecastWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringResource("alerts.title", bundle: .module, table: "Menu"))
                .font(.app(.satoshiRegular, size: 12))
                .foregroundStyle(.secondary)
            ForEach(warnings) { warning in
                HStack {
                    Circle()
                        .fill(color(for: warning.severity))
                        .frame(width: 8, height: 8)
                    Text(warning.message)
                        .font(.app(.satoshiMedium, size: 12))
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
        }
        .maxFrame(true, alignment: .leading)
    }

    private func color(for severity: ForecastSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private struct AggregationsSection: View {
    let aggregations: [UsageAggregationMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringResource("aggregations.title", bundle: .module, table: "Menu"))
                .font(.app(.satoshiRegular, size: 12))
                .foregroundStyle(.secondary)
            ForEach(aggregations) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.preset.displayName)
                        .font(.app(.satoshiMedium, size: 12))
                    ForEach(metric.rows.suffix(3)) { row in
                        HStack {
                            Text(row.startDate, style: .time)
                                .font(.app(.satoshiRegular, size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("$\(Double(row.spendCents) / 100.0, specifier: \"%.2f\")")
                                .font(.app(.satoshiMedium, size: 11))
                        }
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(10)
            }
        }
        .maxFrame(true, alignment: .leading)
    }
}

private struct LiveUsageSection: View {
    let metrics: LiveUsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringResource("live.title", bundle: .module, table: "Menu"))
                .font(.app(.satoshiRegular, size: 12))
                .foregroundStyle(.secondary)
            Sparkline(points: metrics.sparklinePoints)
                .frame(height: 40)
            Text("Burn: $\(metrics.burnRateCentsPerHour / 100.0, specifier: \"%.2f\") / hr")
                .font(.app(.satoshiMedium, size: 12))
        }
        .maxFrame(true, alignment: .leading)
    }
}

private struct Sparkline: View {
    let points: [Double]

    func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard let max = points.max(), let min = points.min(), max != min else {
            return points.enumerated().map { index, _ in
                CGPoint(x: size.width * Double(index) / Double(max(points.count - 1, 1)), y: size.height / 2)
            }
        }
        return points.enumerated().map { index, value in
            let x = size.width * Double(index) / Double(max(points.count - 1, 1))
            let normalized = (value - min) / (max - min)
            let y = size.height * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let pts = normalizedPoints(in: proxy.size)
            Path { path in
                guard let first = pts.first else { return }
                path.move(to: first)
                for point in pts.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
