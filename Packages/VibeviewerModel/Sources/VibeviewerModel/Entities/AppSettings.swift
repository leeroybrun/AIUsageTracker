import Foundation
import Observation

@Observable
public final class AppSettings: Codable, Sendable, Equatable {
    public var launchAtLogin: Bool
    public var usageHistory: AppSettings.UsageHistory
    public var overview: AppSettings.Overview
    public var pauseOnScreenSleep: Bool
    public var appearance: AppAppearance
    public var analyticsDataDays: Int
    public var providerSettings: ProviderSettings
    public var advanced: Advanced

    public init(
        launchAtLogin: Bool = false,
        usageHistory: AppSettings.UsageHistory = AppSettings.UsageHistory(limit: 5),
        overview: AppSettings.Overview = AppSettings.Overview(refreshInterval: 5),
        pauseOnScreenSleep: Bool = false,
        appearance: AppAppearance = .system,
        analyticsDataDays: Int = 7,
        providerSettings: ProviderSettings = .init(),
        advanced: Advanced = .init()
    ) {
        self.launchAtLogin = launchAtLogin
        self.usageHistory = usageHistory
        self.overview = overview
        self.pauseOnScreenSleep = pauseOnScreenSleep
        self.appearance = appearance
        self.analyticsDataDays = analyticsDataDays
        self.providerSettings = providerSettings
        self.advanced = advanced
    }

    public static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.launchAtLogin == rhs.launchAtLogin &&
            lhs.usageHistory == rhs.usageHistory &&
            lhs.overview == rhs.overview &&
            lhs.pauseOnScreenSleep == rhs.pauseOnScreenSleep &&
            lhs.appearance == rhs.appearance &&
            lhs.analyticsDataDays == rhs.analyticsDataDays &&
            lhs.providerSettings == rhs.providerSettings &&
            lhs.advanced == rhs.advanced
    }

    // MARK: - Codable (backward compatible)

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case usageHistory
        case overview
        case pauseOnScreenSleep
        case appearance
        case analyticsDataDays
        case providerSettings
        case advanced
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        let usageHistory = try container.decodeIfPresent(AppSettings.UsageHistory.self, forKey: .usageHistory) ?? AppSettings.UsageHistory(limit: 5)
        let overview = try container.decodeIfPresent(AppSettings.Overview.self, forKey: .overview) ?? AppSettings.Overview(refreshInterval: 5)
        let pauseOnScreenSleep = try container.decodeIfPresent(Bool.self, forKey: .pauseOnScreenSleep) ?? false
        let appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        let analyticsDataDays = try container.decodeIfPresent(Int.self, forKey: .analyticsDataDays) ?? 7
        let providerSettings = try container.decodeIfPresent(ProviderSettings.self, forKey: .providerSettings) ?? .init()
        let advanced = try container.decodeIfPresent(Advanced.self, forKey: .advanced) ?? .init()
        self.init(
            launchAtLogin: launchAtLogin,
            usageHistory: usageHistory,
            overview: overview,
            pauseOnScreenSleep: pauseOnScreenSleep,
            appearance: appearance,
            analyticsDataDays: analyticsDataDays,
            providerSettings: providerSettings,
            advanced: advanced
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.launchAtLogin, forKey: .launchAtLogin)
        try container.encode(self.usageHistory, forKey: .usageHistory)
        try container.encode(self.overview, forKey: .overview)
        try container.encode(self.pauseOnScreenSleep, forKey: .pauseOnScreenSleep)
        try container.encode(self.appearance, forKey: .appearance)
        try container.encode(self.analyticsDataDays, forKey: .analyticsDataDays)
        try container.encode(self.providerSettings, forKey: .providerSettings)
        try container.encode(self.advanced, forKey: .advanced)
    }

    public struct Overview: Codable, Sendable, Equatable {
        public var refreshInterval: Int

        public init(
            refreshInterval: Int = 5
        ) {
            self.refreshInterval = refreshInterval
        }
    }

    public struct UsageHistory: Codable, Sendable, Equatable {
        public var limit: Int

        public init(
            limit: Int = 5
        ) {
            self.limit = limit
        }
    }

    public struct ProviderSettings: Codable, Sendable, Equatable {
        public var enableOpenAI: Bool
        public var enableAnthropic: Bool
        public var enableGoogleGemini: Bool
        public var openAIKeyReference: SecureCredentialReference?
        public var openAIOrganization: String?
        public var anthropicKeyReference: SecureCredentialReference?
        public var googleServiceAccountReference: SecureCredentialReference?
        public var googleProjectID: String
        public var googleBillingAccountID: String
        public var pendingSecretMigration: PendingSecretMigration?

        public struct PendingSecretMigration: Sendable, Equatable {
            public var openAIAPIKey: String?
            public var anthropicAPIKey: String?
            public var googleServiceAccountJSON: String?

            public init(
                openAIAPIKey: String? = nil,
                anthropicAPIKey: String? = nil,
                googleServiceAccountJSON: String? = nil
            ) {
                self.openAIAPIKey = openAIAPIKey
                self.anthropicAPIKey = anthropicAPIKey
                self.googleServiceAccountJSON = googleServiceAccountJSON
    }

    public struct Advanced: Codable, Sendable, Equatable {
        public var logRetentionDays: Int
        public var enableProxyIngestion: Bool
        public var proxyPort: Int
        public var statusExportPath: String
        public var notificationThresholdPercent: Double
        public var autoDetectPreferences: Bool
        public var enableDeveloperWebSocket: Bool
        public var developerWebSocketPort: Int
        public var enableDiagnosticsLogging: Bool
        public var showAlertBadge: Bool

        public init(
            logRetentionDays: Int = 14,
            enableProxyIngestion: Bool = false,
            proxyPort: Int = 7788,
            statusExportPath: String = "~/Library/Application Support/AIUsageTracker/status.json",
            notificationThresholdPercent: Double = 0.8,
            autoDetectPreferences: Bool = true,
            enableDeveloperWebSocket: Bool = false,
            developerWebSocketPort: Int = 8790,
            enableDiagnosticsLogging: Bool = true,
            showAlertBadge: Bool = true
        ) {
            self.logRetentionDays = logRetentionDays
            self.enableProxyIngestion = enableProxyIngestion
            self.proxyPort = proxyPort
            self.statusExportPath = statusExportPath
            self.notificationThresholdPercent = notificationThresholdPercent
            self.autoDetectPreferences = autoDetectPreferences
            self.enableDeveloperWebSocket = enableDeveloperWebSocket
            self.developerWebSocketPort = developerWebSocketPort
            self.enableDiagnosticsLogging = enableDiagnosticsLogging
            self.showAlertBadge = showAlertBadge
        }

        private enum CodingKeys: String, CodingKey {
            case logRetentionDays
            case enableProxyIngestion
            case proxyPort
            case statusExportPath
            case notificationThresholdPercent
            case autoDetectPreferences
            case enableDeveloperWebSocket
            case developerWebSocketPort
            case enableDiagnosticsLogging
            case showAlertBadge
        }
    }
}

        public init(
            enableOpenAI: Bool = false,
            enableAnthropic: Bool = false,
            enableGoogleGemini: Bool = false,
            openAIKeyReference: SecureCredentialReference? = .openAIAPIKey,
            openAIOrganization: String? = nil,
            anthropicKeyReference: SecureCredentialReference? = .anthropicAPIKey,
            googleServiceAccountReference: SecureCredentialReference? = .googleServiceAccount,
            googleProjectID: String = "",
            googleBillingAccountID: String = "",
            pendingSecretMigration: PendingSecretMigration? = nil
        ) {
            self.enableOpenAI = enableOpenAI
            self.enableAnthropic = enableAnthropic
            self.enableGoogleGemini = enableGoogleGemini
            self.openAIKeyReference = openAIKeyReference
            self.openAIOrganization = openAIOrganization
            self.anthropicKeyReference = anthropicKeyReference
            self.googleServiceAccountReference = googleServiceAccountReference
            self.googleProjectID = googleProjectID
            self.googleBillingAccountID = googleBillingAccountID
            self.pendingSecretMigration = pendingSecretMigration
        }

        private enum CodingKeys: String, CodingKey {
            case enableOpenAI
            case enableAnthropic
            case enableGoogleGemini
            case openAIKeyReference
            case openAIOrganization
            case anthropicKeyReference
            case googleServiceAccountReference
            case googleProjectID
            case googleBillingAccountID
            // Legacy keys for migration
            case openAIAPIKey
            case anthropicAPIKey
            case googleServiceAccountJSON
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.enableOpenAI = try container.decodeIfPresent(Bool.self, forKey: .enableOpenAI) ?? false
            self.enableAnthropic = try container.decodeIfPresent(Bool.self, forKey: .enableAnthropic) ?? false
            self.enableGoogleGemini = try container.decodeIfPresent(Bool.self, forKey: .enableGoogleGemini) ?? false
            self.openAIKeyReference = try container.decodeIfPresent(SecureCredentialReference.self, forKey: .openAIKeyReference) ?? .openAIAPIKey
            self.openAIOrganization = try container.decodeIfPresent(String.self, forKey: .openAIOrganization)
            self.anthropicKeyReference = try container.decodeIfPresent(SecureCredentialReference.self, forKey: .anthropicKeyReference) ?? .anthropicAPIKey
            self.googleServiceAccountReference = try container.decodeIfPresent(SecureCredentialReference.self, forKey: .googleServiceAccountReference) ?? .googleServiceAccount
            self.googleProjectID = try container.decodeIfPresent(String.self, forKey: .googleProjectID) ?? ""
            self.googleBillingAccountID = try container.decodeIfPresent(String.self, forKey: .googleBillingAccountID) ?? ""

            let legacyOpenAI = try container.decodeIfPresent(String.self, forKey: .openAIAPIKey)
            let legacyAnthropic = try container.decodeIfPresent(String.self, forKey: .anthropicAPIKey)
            let legacyGoogle = try container.decodeIfPresent(String.self, forKey: .googleServiceAccountJSON)
            if legacyOpenAI != nil || legacyAnthropic != nil || legacyGoogle != nil {
                self.pendingSecretMigration = .init(
                    openAIAPIKey: legacyOpenAI,
                    anthropicAPIKey: legacyAnthropic,
                    googleServiceAccountJSON: legacyGoogle
                )
            } else {
                self.pendingSecretMigration = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.enableOpenAI, forKey: .enableOpenAI)
            try container.encode(self.enableAnthropic, forKey: .enableAnthropic)
            try container.encode(self.enableGoogleGemini, forKey: .enableGoogleGemini)
            try container.encodeIfPresent(self.openAIKeyReference, forKey: .openAIKeyReference)
            try container.encodeIfPresent(self.openAIOrganization, forKey: .openAIOrganization)
            try container.encodeIfPresent(self.anthropicKeyReference, forKey: .anthropicKeyReference)
            try container.encodeIfPresent(self.googleServiceAccountReference, forKey: .googleServiceAccountReference)
            try container.encode(self.googleProjectID, forKey: .googleProjectID)
            try container.encode(self.googleBillingAccountID, forKey: .googleBillingAccountID)
        }

        public static func == (lhs: ProviderSettings, rhs: ProviderSettings) -> Bool {
            lhs.enableOpenAI == rhs.enableOpenAI &&
                lhs.enableAnthropic == rhs.enableAnthropic &&
                lhs.enableGoogleGemini == rhs.enableGoogleGemini &&
                lhs.openAIKeyReference == rhs.openAIKeyReference &&
                lhs.openAIOrganization == rhs.openAIOrganization &&
                lhs.anthropicKeyReference == rhs.anthropicKeyReference &&
                lhs.googleServiceAccountReference == rhs.googleServiceAccountReference &&
                lhs.googleProjectID == rhs.googleProjectID &&
                lhs.googleBillingAccountID == rhs.googleBillingAccountID
        }
    }

    // moved to its own file: AppAppearance
}
