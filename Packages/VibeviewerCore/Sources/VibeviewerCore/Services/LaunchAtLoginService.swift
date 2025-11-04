import Foundation

public protocol LaunchAtLoginService {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) -> Bool
}

#if canImport(ServiceManagement)
import ServiceManagement

public final class DefaultLaunchAtLoginService: LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return true
                }
                try SMAppService.mainApp.register()
                return true
            } else {
                if SMAppService.mainApp.status != .enabled {
                    return true
                }
                try SMAppService.mainApp.unregister()
                return true
            }
        } catch {
            let action = enabled ? "enable" : "disable"
            print("Failed to \(action) launch at login: \(error)")
            return false
        }
    }
}
#else

public final class DefaultLaunchAtLoginService: LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool { false }

    public func setEnabled(_ enabled: Bool) -> Bool { false }
}

#endif
