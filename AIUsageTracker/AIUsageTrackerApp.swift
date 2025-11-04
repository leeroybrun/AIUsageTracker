import Observation
import SwiftUI
import VibeviewerAPI
import VibeviewerAppEnvironment
import VibeviewerCore
import VibeviewerLoginUI
import VibeviewerMenuUI
import VibeviewerModel
import VibeviewerSettingsUI
import VibeviewerStorage
import VibeviewerShareUI

@main
struct AIUsageTrackerApp: App {
    private let secureStore: DefaultSecureCredentialStore
    private let storageService: DefaultCursorStorageService
    private let credentialResolver: DefaultProviderCredentialResolver
    private let developerBridge = DeveloperBridge.shared
    private let proxyServer = UsageProxyServer.shared
    private let notificationCoordinator = NotificationCoordinator.shared

    @State private var settings: AppSettings
    @State private var session: VibeviewerModel.AppSession
    @State private var refresher: any DashboardRefreshService = NoopDashboardRefreshService()

    init() {
        let secureStore = DefaultSecureCredentialStore()
        self.secureStore = secureStore
        let storage = DefaultCursorStorageService(secureStore: secureStore)
        self.storageService = storage
        self.credentialResolver = DefaultProviderCredentialResolver(secureStore: secureStore)
        let initialSettings = DefaultCursorStorageService.loadSettingsSync()
        let initialSession = VibeviewerModel.AppSession(
            credentials: DefaultCursorStorageService.loadCredentialsSync(),
            snapshot: DefaultCursorStorageService.loadDashboardSnapshotSync()
        )
        _settings = State(initialValue: initialSettings)
        _session = State(initialValue: initialSession)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView()
                .environment(\.cursorService, DefaultCursorService())
                .environment(\.cursorStorage, storageService)
                .environment(\.secureCredentialStore, secureStore)
                .environment(\.loginWindowManager, LoginWindowManager.shared)
                .environment(\.settingsWindowManager, SettingsWindowManager.shared)
                .environment(\.dashboardRefreshService, self.refresher)
                .environment(\.launchAtLoginService, DefaultLaunchAtLoginService())
                .environment(self.settings)
                .environment(self.session)
                .menuBarExtraWindowCorner()
                .onAppear {
                    SettingsWindowManager.shared.appSettings = self.settings
                    SettingsWindowManager.shared.appSession = self.session
                    SettingsWindowManager.shared.secureStore = self.secureStore
                }
                .id(self.settings.appearance)
                .applyPreferredColorScheme(self.settings.appearance)
        } label: {
            menuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
        .onChange(of: settings.advanced) { newValue in
            Task {
                if newValue.enableProxyIngestion {
                    await proxyServer.start(port: UInt16(newValue.proxyPort), retentionDays: newValue.logRetentionDays)
                } else {
                    await proxyServer.stop()
                }
                await developerBridge.update(snapshot: session.snapshot, settings: settings)
            }
        }
        .onChange(of: session.snapshot) { newSnapshot in
            Task {
                await developerBridge.update(snapshot: newSnapshot, settings: settings)
                if let snapshot = newSnapshot {
                    await notificationCoordinator.postWarnings(snapshot.forecastWarnings)
                    updateBadge(for: snapshot)
                }
            }
        }
    }

    private func menuBarLabel() -> some View {
        HStack(spacing: 6) {
            GaugeIcon(snapshot: session.snapshot, settings: settings)
                .frame(width: 20, height: 20)
            Text(menuBarSummaryText(snapshot: session.snapshot))
                .font(.app(.satoshiBold, size: 15))
                .foregroundColor(.primary)
        }
        .task {
            await self.setupDashboardRefreshService()
            Task { await developerBridge.update(snapshot: session.snapshot, settings: settings) }
            if settings.advanced.enableProxyIngestion {
                await proxyServer.start(port: UInt16(settings.advanced.proxyPort), retentionDays: settings.advanced.logRetentionDays)
            }
            await notificationCoordinator.requestAuthorization()
            }
    }

    @MainActor
    private func updateBadge(for snapshot: DashboardSnapshot) {
        guard settings.advanced.showAlertBadge else {
            NSApplication.shared.dockTile.badgeLabel = nil
            return
        }
        let critical = snapshot.forecastWarnings.contains { $0.severity != .info }
        NSApplication.shared.dockTile.badgeLabel = critical ? "!" : nil
    }

    private func menuBarSummaryText(snapshot: DashboardSnapshot?) -> String {
        guard let snapshot else { return "" }
        if let export = snapshot.developerExport {
            return export.statusLine
        }
        if let usageSummary = snapshot.usageSummary {
            let planUsed = usageSummary.individualUsage.plan.used
            let onDemandUsed = usageSummary.individualUsage.onDemand?.used ?? 0
            let providerCents = snapshot.providerTotals
                .filter { $0.provider != .cursor }
                .reduce(0) { $0 + $1.spendCents }
            let totalUsageCents = planUsed + onDemandUsed + providerCents
            return totalUsageCents.dollarStringFromCents
        } else {
            let providerCents = snapshot.providerTotals
                .filter { $0.provider != .cursor }
                .reduce(0) { $0 + $1.spendCents }
            let total = snapshot.spendingCents + providerCents
            return total.dollarStringFromCents
        }
    }

    private func setupDashboardRefreshService() async {
        let dashboardRefreshSvc = DefaultDashboardRefreshService(
            api: DefaultCursorService(),
            storage: storageService,
            settings: self.settings,
            session: self.session,
            credentialResolver: self.credentialResolver
        )
        let screenPowerSvc = DefaultScreenPowerStateService()
        let powerAwareSvc = PowerAwareDashboardRefreshService(
            refreshService: dashboardRefreshSvc,
            screenPowerService: screenPowerSvc
        )
        self.refresher = powerAwareSvc
        await self.refresher.start()
    }
}

private struct GaugeIcon: View {
    let snapshot: DashboardSnapshot?
    let settings: AppSettings

    var progress: Double {
        guard let summary = snapshot?.usageSummary else { return 0 }
        let used = Double(summary.individualUsage.plan.used + (summary.individualUsage.onDemand?.used ?? 0))
        let limit = Double(summary.individualUsage.plan.limit)
        guard limit > 0 else { return min(used / 100_000.0, 1.0) }
        return min(max(used / limit, 0), 1)
    }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let background = Path(ellipseIn: rect)
            context.stroke(background, with: .color(.primary.opacity(0.2)), lineWidth: 2)
            let startAngle = Angle(degrees: -90)
            let endAngle = Angle(degrees: -90 + 360 * progress)
            let gaugePath = Path { path in
                path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2 - 1, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            }
            let color: Color
            if progress < settings.advanced.notificationThresholdPercent {
                color = .green
            } else if progress < 1.0 {
                color = .orange
            } else {
                color = .red
            }
            context.stroke(gaugePath, with: .color(color), lineWidth: 3)
        }
    }
}

