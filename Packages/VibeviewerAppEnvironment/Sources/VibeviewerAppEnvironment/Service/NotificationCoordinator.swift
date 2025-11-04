import Foundation
import VibeviewerModel

#if canImport(UserNotifications)
import UserNotifications

public actor NotificationCoordinator {
    public static let shared = NotificationCoordinator()
    private var permissionRequested = false
    private var lastNotificationIDs: Set<String> = []

    public func requestAuthorization() async {
        guard !permissionRequested else { return }
        permissionRequested = true
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // ignore
        }
    }

    public func postWarnings(_ warnings: [ForecastWarning]) async {
        guard !warnings.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        for warning in warnings {
            let identifier = warning.id.uuidString
            if lastNotificationIDs.contains(identifier) { continue }
            let content = UNMutableNotificationContent()
            content.title = "Usage Alert"
            content.body = warning.message
            switch warning.severity {
            case .info:
                content.sound = .default
            case .warning:
                content.sound = UNNotificationSound(named: UNNotificationSoundName("warning.wav"))
            case .critical:
                content.sound = .defaultCritical
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
            lastNotificationIDs.insert(identifier)
        }
    }
}
#else

public actor NotificationCoordinator {
    public static let shared = NotificationCoordinator()

    public func requestAuthorization() async {}

    public func postWarnings(_ warnings: [ForecastWarning]) async {}
}
#endif
