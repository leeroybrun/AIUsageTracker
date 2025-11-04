import Foundation

public struct SecureCredentialReference: Codable, Sendable, Hashable, Equatable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

public extension SecureCredentialReference {
    static let cursorCredentials = SecureCredentialReference(identifier: "com.aiusagetracker.secure.cursor.credentials")
    static let openAIAPIKey = SecureCredentialReference(identifier: "com.aiusagetracker.secure.openai.apiKey")
    static let anthropicAPIKey = SecureCredentialReference(identifier: "com.aiusagetracker.secure.anthropic.apiKey")
    static let googleServiceAccount = SecureCredentialReference(identifier: "com.aiusagetracker.secure.google.serviceAccount")
}
