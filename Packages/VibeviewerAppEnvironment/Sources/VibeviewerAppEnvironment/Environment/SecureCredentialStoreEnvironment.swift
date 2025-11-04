import SwiftUI
import VibeviewerStorage

private struct SecureCredentialStoreKey: EnvironmentKey {
    static let defaultValue: any SecureCredentialStore = DefaultSecureCredentialStore()
}

public extension EnvironmentValues {
    var secureCredentialStore: any SecureCredentialStore {
        get { self[SecureCredentialStoreKey.self] }
        set { self[SecureCredentialStoreKey.self] = newValue }
    }
}
