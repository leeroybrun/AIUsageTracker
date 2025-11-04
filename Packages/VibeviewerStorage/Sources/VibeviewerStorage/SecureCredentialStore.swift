import Foundation
import VibeviewerModel

public enum SecureCredentialStoreError: Error, Equatable {
    case operationFailed(status: OSStatus)
}

public protocol SecureCredentialStore: Sendable {
    func setSecret(_ secret: Data, for reference: SecureCredentialReference) throws
    func secret(for reference: SecureCredentialReference) throws -> Data?
    func deleteSecret(for reference: SecureCredentialReference) throws
    func containsSecret(for reference: SecureCredentialReference) throws -> Bool
}

public extension SecureCredentialStore {
    func containsSecret(for reference: SecureCredentialReference) throws -> Bool {
        try self.secret(for: reference) != nil
    }
}

#if canImport(Security)
import Security

public final class DefaultSecureCredentialStore: @unchecked Sendable, SecureCredentialStore {
    private let service: String

    public init(service: String = "com.aiusagetracker.securestore") {
        self.service = service
    }

    public func setSecret(_ secret: Data, for reference: SecureCredentialReference) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.identifier
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw SecureCredentialStoreError.operationFailed(status: updateStatus)
            }
        case errSecItemNotFound:
            var insert = query
            insert.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecureCredentialStoreError.operationFailed(status: addStatus)
            }
        default:
            throw SecureCredentialStoreError.operationFailed(status: status)
        }
    }

    public func secret(for reference: SecureCredentialReference) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw SecureCredentialStoreError.operationFailed(status: status)
        }
    }

    public func deleteSecret(for reference: SecureCredentialReference) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.identifier
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureCredentialStoreError.operationFailed(status: status)
        }
    }
}

#else

public final class DefaultSecureCredentialStore: @unchecked Sendable, SecureCredentialStore {
    private static var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func setSecret(_ secret: Data, for reference: SecureCredentialReference) throws {
        lock.lock()
        DefaultSecureCredentialStore.storage[reference.identifier] = secret
        lock.unlock()
    }

    public func secret(for reference: SecureCredentialReference) throws -> Data? {
        lock.lock()
        let value = DefaultSecureCredentialStore.storage[reference.identifier]
        lock.unlock()
        return value
    }

    public func deleteSecret(for reference: SecureCredentialReference) throws {
        lock.lock()
        DefaultSecureCredentialStore.storage.removeValue(forKey: reference.identifier)
        lock.unlock()
    }
}

#endif
