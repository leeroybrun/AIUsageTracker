import Foundation
import VibeviewerAPI
import VibeviewerModel

public struct DefaultProviderCredentialResolver: ProviderCredentialResolving {
    private let secureStore: any SecureCredentialStore

    public init(secureStore: any SecureCredentialStore) {
        self.secureStore = secureStore
    }

    public func secret(for reference: SecureCredentialReference) throws -> String? {
        guard let data = try secureStore.secret(for: reference) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
