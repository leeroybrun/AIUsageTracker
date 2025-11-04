import Foundation
import VibeviewerModel

public enum CursorStorageKeys {
    public static let credentials = "cursor.credentials.v1"
    public static let settings = "app.settings.v1"
    public static let dashboardSnapshot = "cursor.dashboard.snapshot.v1"
}

public struct DefaultCursorStorageService: CursorStorageService, CursorStorageSyncHelpers {
    private let defaults: UserDefaults
    private let secureStore: any SecureCredentialStore

    public init(userDefaults: UserDefaults = .standard, secureStore: any SecureCredentialStore = DefaultSecureCredentialStore()) {
        self.defaults = userDefaults
        self.secureStore = secureStore
    }

    // MARK: - Credentials

    public func saveCredentials(_ me: Credentials) async throws {
        let data = try JSONEncoder().encode(me)
        try self.secureStore.setSecret(data, for: .cursorCredentials)
        self.defaults.removeObject(forKey: CursorStorageKeys.credentials)
    }

    public func loadCredentials() async -> Credentials? {
        if let data = try? self.secureStore.secret(for: .cursorCredentials) {
            return try? JSONDecoder().decode(Credentials.self, from: data)
        }
        if let legacy = self.defaults.data(forKey: CursorStorageKeys.credentials),
           let decoded = try? JSONDecoder().decode(Credentials.self, from: legacy)
        {
            try? self.secureStore.setSecret(legacy, for: .cursorCredentials)
            self.defaults.removeObject(forKey: CursorStorageKeys.credentials)
            return decoded
        }
        return nil
    }

    public func clearCredentials() async {
        try? self.secureStore.deleteSecret(for: .cursorCredentials)
        self.defaults.removeObject(forKey: CursorStorageKeys.credentials)
    }

    // MARK: - Dashboard Snapshot

    public func saveDashboardSnapshot(_ snapshot: DashboardSnapshot) async throws {
        let data = try JSONEncoder().encode(snapshot)
        self.defaults.set(data, forKey: CursorStorageKeys.dashboardSnapshot)
    }

    public func loadDashboardSnapshot() async -> DashboardSnapshot? {
        guard let data = self.defaults.data(forKey: CursorStorageKeys.dashboardSnapshot) else { return nil }
        return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
    }

    public func clearDashboardSnapshot() async {
        self.defaults.removeObject(forKey: CursorStorageKeys.dashboardSnapshot)
    }

    // MARK: - App Settings

    public func saveSettings(_ settings: AppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        self.defaults.set(data, forKey: CursorStorageKeys.settings)
    }

    public func loadSettings() async -> AppSettings {
        var settings: AppSettings
        if let data = self.defaults.data(forKey: CursorStorageKeys.settings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            settings = decoded
        } else {
            settings = AppSettings()
        }
        let migrated = migrateProviderSecretsIfNeeded(settings)
        settings = migrated
        if let config = AdvancedConfigManager.shared.loadConfiguration() {
            var merged = settings
            config.merged(into: &merged)
            settings = merged
        }
        if settings != migrated {
            try? await saveSettings(settings)
        }
        return settings
    }
    
    // MARK: - AppSession Management
    
    public func clearAppSession() async {
        await clearCredentials()
        await clearDashboardSnapshot()
        try? self.secureStore.deleteSecret(for: .openAIAPIKey)
        try? self.secureStore.deleteSecret(for: .anthropicAPIKey)
        try? self.secureStore.deleteSecret(for: .googleServiceAccount)
    }

    // MARK: - Sync Helpers

    public static func loadCredentialsSync() -> Credentials? {
        let store = DefaultSecureCredentialStore()
        if let data = try? store.secret(for: .cursorCredentials) {
            return try? JSONDecoder().decode(Credentials.self, from: data)
        }
        let defaults = UserDefaults.standard
        if let legacy = defaults.data(forKey: CursorStorageKeys.credentials),
           let decoded = try? JSONDecoder().decode(Credentials.self, from: legacy)
        {
            try? store.setSecret(legacy, for: .cursorCredentials)
            defaults.removeObject(forKey: CursorStorageKeys.credentials)
            return decoded
        }
        return nil
    }

    public static func loadDashboardSnapshotSync() -> DashboardSnapshot? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: CursorStorageKeys.dashboardSnapshot) else { return nil }
        return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
    }

    public static func loadSettingsSync() -> AppSettings {
        let defaults = UserDefaults.standard
        let store = DefaultSecureCredentialStore()
        var decoded: AppSettings
        if let data = defaults.data(forKey: CursorStorageKeys.settings),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            decoded = settings
        } else {
            decoded = AppSettings()
        }
        let service = DefaultCursorStorageService(userDefaults: defaults, secureStore: store)
        let migrated = service.migrateProviderSecretsIfNeeded(decoded)
        decoded = migrated
        if let config = AdvancedConfigManager.shared.loadConfiguration() {
            var merged = decoded
            config.merged(into: &merged)
            decoded = merged
        }
        if migrated != decoded {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(decoded) {
                defaults.set(data, forKey: CursorStorageKeys.settings)
            }
        }
        return decoded
    }

    private func migrateProviderSecretsIfNeeded(_ settings: AppSettings) -> AppSettings {
        var updated = settings
        guard let migration = updated.providerSettings.pendingSecretMigration else {
            return updated
        }

        if let value = migration.openAIAPIKey, value.isEmpty == false,
           let data = value.data(using: .utf8)
        {
            try? self.secureStore.setSecret(data, for: .openAIAPIKey)
            updated.providerSettings.openAIKeyReference = .openAIAPIKey
        }
        if let value = migration.anthropicAPIKey, value.isEmpty == false,
           let data = value.data(using: .utf8)
        {
            try? self.secureStore.setSecret(data, for: .anthropicAPIKey)
            updated.providerSettings.anthropicKeyReference = .anthropicAPIKey
        }
        if let value = migration.googleServiceAccountJSON, value.isEmpty == false,
           let data = value.data(using: .utf8)
        {
            try? self.secureStore.setSecret(data, for: .googleServiceAccount)
            updated.providerSettings.googleServiceAccountReference = .googleServiceAccount
        }
        updated.providerSettings.pendingSecretMigration = nil
        return updated
    }
}
