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

    public init(
        launchAtLogin: Bool = false,
        usageHistory: AppSettings.UsageHistory = AppSettings.UsageHistory(limit: 5),
        overview: AppSettings.Overview = AppSettings.Overview(refreshInterval: 5),
        pauseOnScreenSleep: Bool = false,
        appearance: AppAppearance = .system,
        analyticsDataDays: Int = 7,
        providerSettings: ProviderSettings = .init()
    ) {
        self.launchAtLogin = launchAtLogin
        self.usageHistory = usageHistory
        self.overview = overview
        self.pauseOnScreenSleep = pauseOnScreenSleep
        self.appearance = appearance
        self.analyticsDataDays = analyticsDataDays
        self.providerSettings = providerSettings
    }

    public static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.launchAtLogin == rhs.launchAtLogin &&
            lhs.usageHistory == rhs.usageHistory &&
            lhs.overview == rhs.overview &&
            lhs.pauseOnScreenSleep == rhs.pauseOnScreenSleep &&
            lhs.appearance == rhs.appearance &&
            lhs.analyticsDataDays == rhs.analyticsDataDays &&
            lhs.providerSettings == rhs.providerSettings
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
        self.init(
            launchAtLogin: launchAtLogin,
            usageHistory: usageHistory,
            overview: overview,
            pauseOnScreenSleep: pauseOnScreenSleep,
            appearance: appearance,
            analyticsDataDays: analyticsDataDays,
            providerSettings: providerSettings
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
        public var openAIAPIKey: String
        public var openAIOrganization: String?
        public var anthropicAPIKey: String
        public var googleServiceAccountJSON: String
        public var googleProjectID: String
        public var googleBillingAccountID: String

        public init(
            enableOpenAI: Bool = false,
            enableAnthropic: Bool = false,
            enableGoogleGemini: Bool = false,
            openAIAPIKey: String = "",
            openAIOrganization: String? = nil,
            anthropicAPIKey: String = "",
            googleServiceAccountJSON: String = "",
            googleProjectID: String = "",
            googleBillingAccountID: String = ""
        ) {
            self.enableOpenAI = enableOpenAI
            self.enableAnthropic = enableAnthropic
            self.enableGoogleGemini = enableGoogleGemini
            self.openAIAPIKey = openAIAPIKey
            self.openAIOrganization = openAIOrganization
            self.anthropicAPIKey = anthropicAPIKey
            self.googleServiceAccountJSON = googleServiceAccountJSON
            self.googleProjectID = googleProjectID
            self.googleBillingAccountID = googleBillingAccountID
        }
    }

    // moved to its own file: AppAppearance
}
