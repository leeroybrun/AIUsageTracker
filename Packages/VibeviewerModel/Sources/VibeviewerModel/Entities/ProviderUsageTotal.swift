import Foundation

public enum UsageProviderKind: String, Codable, CaseIterable, Sendable {
    case cursor
    case openAI
    case anthropic
    case googleGemini

    public var displayName: String {
        switch self {
        case .cursor:
            return "Cursor"
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .googleGemini:
            return "Google Gemini"
        }
    }
}

public struct ProviderUsageTotal: Codable, Identifiable, Equatable, Sendable {
    public let provider: UsageProviderKind
    public let spendCents: Int
    public let requestCount: Int
    public let currencyCode: String
    public let lastSyncedAt: Date

    public init(
        provider: UsageProviderKind,
        spendCents: Int,
        requestCount: Int,
        currencyCode: String = "USD",
        lastSyncedAt: Date = .now
    ) {
        self.provider = provider
        self.spendCents = spendCents
        self.requestCount = requestCount
        self.currencyCode = currencyCode
        self.lastSyncedAt = lastSyncedAt
    }

    public var id: UsageProviderKind { self.provider }
}
