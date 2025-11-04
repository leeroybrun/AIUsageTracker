import Foundation
import VibeviewerModel

public struct AdvancedAppConfiguration: Codable, Sendable {
    public var logRetentionDays: Int?
    public var enableProxyIngestion: Bool?
    public var proxyPort: Int?
    public var statusExportPath: String?
    public var notificationThresholdPercent: Double?
    public var autoDetectPreferences: Bool?
    public var enableDeveloperWebSocket: Bool?
    public var developerWebSocketPort: Int?
    public var enableDiagnosticsLogging: Bool?
    public var showAlertBadge: Bool?

    public init() {}

    public func merged(into settings: inout AppSettings) {
        if let logRetentionDays { settings.advanced.logRetentionDays = logRetentionDays }
        if let enableProxyIngestion { settings.advanced.enableProxyIngestion = enableProxyIngestion }
        if let proxyPort { settings.advanced.proxyPort = proxyPort }
        if let statusExportPath { settings.advanced.statusExportPath = statusExportPath }
        if let notificationThresholdPercent { settings.advanced.notificationThresholdPercent = notificationThresholdPercent }
        if let autoDetectPreferences { settings.advanced.autoDetectPreferences = autoDetectPreferences }
        if let enableDeveloperWebSocket { settings.advanced.enableDeveloperWebSocket = enableDeveloperWebSocket }
        if let developerWebSocketPort { settings.advanced.developerWebSocketPort = developerWebSocketPort }
        if let enableDiagnosticsLogging { settings.advanced.enableDiagnosticsLogging = enableDiagnosticsLogging }
        if let showAlertBadge { settings.advanced.showAlertBadge = showAlertBadge }
    }
}

public struct AdvancedConfigManager: Sendable {
    public static let shared = AdvancedConfigManager()
    private let configURL: URL
    private let schemaURL: URL

    public init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = support.appendingPathComponent("AIUsageTracker", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.configURL = directory.appendingPathComponent("advanced-config.json")
        self.schemaURL = directory.appendingPathComponent("advanced-config.schema.json")
        self.bootstrapSchemaIfNeeded()
    }

    public func loadConfiguration() -> AdvancedAppConfiguration? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? JSONDecoder().decode(AdvancedAppConfiguration.self, from: data)
    }

    public func save(configuration: AdvancedAppConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: configURL, options: [.atomic])
    }

    private func bootstrapSchemaIfNeeded() {
        guard !FileManager.default.fileExists(atPath: schemaURL.path) else { return }
        let schema = Self.schemaTemplate
        try? schema.data(using: .utf8)?.write(to: schemaURL, options: [.atomic])
    }

    private static let schemaTemplate: String = {
        return """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "AIUsageTrackerAdvancedConfig",
  "type": "object",
  "properties": {
    "logRetentionDays": {"type": "integer", "minimum": 1},
    "enableProxyIngestion": {"type": "boolean"},
    "proxyPort": {"type": "integer", "minimum": 1, "maximum": 65535},
    "statusExportPath": {"type": "string"},
    "notificationThresholdPercent": {"type": "number", "minimum": 0, "maximum": 1},
    "autoDetectPreferences": {"type": "boolean"},
    "enableDeveloperWebSocket": {"type": "boolean"},
    "developerWebSocketPort": {"type": "integer", "minimum": 1, "maximum": 65535},
    "enableDiagnosticsLogging": {"type": "boolean"},
    "showAlertBadge": {"type": "boolean"}
  }
}
"""
    }()
}
