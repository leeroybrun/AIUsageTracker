import Foundation
import VibeviewerModel

public protocol UsageProvider: Sendable {
    var kind: UsageProviderKind { get }
    func fetchTotals(dateRange: DateInterval) async throws -> ProviderUsageTotal?
}

public struct UsageProviderConfiguration {
    public let settings: AppSettings.ProviderSettings

    public init(settings: AppSettings.ProviderSettings) {
        self.settings = settings
    }
}

public enum UsageProviderError: Error {
    case invalidCredentials
    case oauthFailure
}

extension Data {
    func base64URLEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    var pemKeyData: Data? {
        let lines = self.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let joined = lines.joined()
        return Data(base64Encoded: joined)
    }
}

public struct ProviderUsageContext {
    public let settings: AppSettings.ProviderSettings
    public let dateRange: DateInterval

    public init(settings: AppSettings.ProviderSettings, dateRange: DateInterval) {
        self.settings = settings
        self.dateRange = dateRange
    }
}

public struct MultiProviderUsageAggregator: Sendable {
    private let configuration: UsageProviderConfiguration

    public init(configuration: UsageProviderConfiguration) {
        self.configuration = configuration
    }

    public func fetchTotals(dateRange: DateInterval) async -> [ProviderUsageTotal] {
        var providers: [any UsageProvider] = []
        if configuration.settings.enableOpenAI,
           configuration.settings.openAIAPIKey.isEmpty == false
        {
            providers.append(OpenAIUsageProvider(settings: configuration.settings))
        }
        if configuration.settings.enableAnthropic,
           configuration.settings.anthropicAPIKey.isEmpty == false
        {
            providers.append(AnthropicUsageProvider(settings: configuration.settings))
        }
        if configuration.settings.enableGoogleGemini,
           configuration.settings.googleServiceAccountJSON.isEmpty == false,
           configuration.settings.googleProjectID.isEmpty == false,
           configuration.settings.googleBillingAccountID.isEmpty == false
        {
            providers.append(GoogleGeminiUsageProvider(settings: configuration.settings))
        }

        if providers.isEmpty { return [] }

        return await withTaskGroup(of: ProviderUsageTotal?.self) { group in
            for provider in providers {
                group.addTask {
                    try? await provider.fetchTotals(dateRange: dateRange)
                }
            }

            var totals: [ProviderUsageTotal] = []
            for await result in group {
                if let total = result {
                    totals.append(total)
                }
            }
            return totals.sorted { $0.provider.displayName < $1.provider.displayName }
        }
    }
}
