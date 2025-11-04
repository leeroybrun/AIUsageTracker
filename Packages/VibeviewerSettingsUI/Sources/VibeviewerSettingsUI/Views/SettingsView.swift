import Observation
import SwiftUI
import VibeviewerAppEnvironment
import VibeviewerModel
import VibeviewerShareUI
import VibeviewerStorage

public struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.cursorStorage) private var storage
    @Environment(\.launchAtLoginService) private var launchAtLoginService
    @Environment(AppSession.self) private var session
    @Environment(\.secureCredentialStore) private var secureStore
    @Environment(\.cursorService) private var cursorService
    
    @State private var refreshFrequency: String = ""
    @State private var usageHistoryLimit: String = ""
    @State private var pauseOnScreenSleep: Bool = false
    @State private var launchAtLogin: Bool = false
    @State private var appearanceSelection: VibeviewerModel.AppAppearance = .system
    @State private var showingClearSessionAlert: Bool = false
    @State private var analyticsDataDays: String = ""
    @State private var enableOpenAI: Bool = false
    @State private var openAIAPIKey: String = ""
    @State private var openAIOrganization: String = ""
    @State private var openAIHasStoredKey: Bool = false
    @State private var openAIKeyMarkedForDeletion: Bool = false
    @State private var enableAnthropic: Bool = false
    @State private var anthropicAPIKey: String = ""
    @State private var anthropicHasStoredKey: Bool = false
    @State private var anthropicKeyMarkedForDeletion: Bool = false
    @State private var enableGemini: Bool = false
    @State private var googleServiceAccountJSON: String = ""
    @State private var googleProjectID: String = ""
    @State private var googleBillingAccountID: String = ""
    @State private var googleHasStoredCredentials: Bool = false
    @State private var googleCredentialsMarkedForDeletion: Bool = false
    @State private var logRetentionDays: String = ""
    @State private var enableProxyIngestion: Bool = false
    @State private var proxyPort: String = ""
    @State private var statusExportPath: String = ""
    @State private var notificationThresholdPercent: String = ""
    @State private var autoDetectPreferences: Bool = true
    @State private var enableDeveloperWebSocket: Bool = false
    @State private var developerWebSocketPort: String = ""
    @State private var enableDiagnosticsLogging: Bool = true
    @State private var automationMessage: String = ""
    @State private var showAlertBadge: Bool = true

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.app(.satoshiBold, size: 18))
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Picker("Appearance", selection: $appearanceSelection) {
                    Text("System").tag(VibeviewerModel.AppAppearance.system)
                    Text("Light").tag(VibeviewerModel.AppAppearance.light)
                    Text("Dark").tag(VibeviewerModel.AppAppearance.dark)
                }
                .pickerStyle(.segmented)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Frequency (minutes)")
                        .font(.app(.satoshiMedium, size: 12))
                    
                    TextField("5", text: $refreshFrequency)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: refreshFrequency) { oldValue, newValue in
                            refreshFrequency = filterIntegerInput(newValue)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage History Limit")
                        .font(.app(.satoshiMedium, size: 12))
                    
                    TextField("5", text: $usageHistoryLimit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: usageHistoryLimit) { oldValue, newValue in
                            usageHistoryLimit = filterIntegerInput(newValue)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analytics Data Range (days)")
                        .font(.app(.satoshiMedium, size: 12))
                    
                    TextField("7", text: $analyticsDataDays)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: analyticsDataDays) { oldValue, newValue in
                            analyticsDataDays = filterIntegerInput(newValue)
                        }
                }
                
                Toggle("Pause refresh when screen sleeps", isOn: $pauseOnScreenSleep)
                    .font(.app(.satoshiMedium, size: 12))
                
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .font(.app(.satoshiMedium, size: 12))

                Divider().opacity(0.4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Providers")
                        .font(.app(.satoshiBold, size: 14))
                    Text("API keys and service accounts are encrypted in your macOS Keychain and never stored in plain text.")
                        .font(.app(.satoshiMedium, size: 11))
                        .foregroundStyle(.secondary)

                    Toggle("Enable OpenAI", isOn: $enableOpenAI)
                        .font(.app(.satoshiMedium, size: 12))

                    if enableOpenAI {
                        SecureField("OpenAI API Key", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                        if openAIHasStoredKey && openAIAPIKey.isEmpty {
                            Text("Existing key stored in Keychain")
                                .font(.app(.satoshiMedium, size: 11))
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .top) {
                            TextField("OpenAI Organization (optional)", text: $openAIOrganization)
                                .textFieldStyle(.roundedBorder)
                            if openAIHasStoredKey {
                                Button("Remove stored key") {
                                    openAIAPIKey = ""
                                    openAIHasStoredKey = false
                                    openAIKeyMarkedForDeletion = true
                                }
                                .buttonStyle(.plain)
                                .font(.app(.satoshiMedium, size: 11))
                            }
                        }
                    }

                    Toggle("Enable Anthropic", isOn: $enableAnthropic)
                        .font(.app(.satoshiMedium, size: 12))

                    if enableAnthropic {
                        SecureField("Anthropic API Key", text: $anthropicAPIKey)
                            .textFieldStyle(.roundedBorder)
                        if anthropicHasStoredKey && anthropicAPIKey.isEmpty {
                            Text("Existing key stored in Keychain")
                                .font(.app(.satoshiMedium, size: 11))
                                .foregroundStyle(.secondary)
                        }
                        if anthropicHasStoredKey {
                            Button("Remove stored key") {
                                anthropicAPIKey = ""
                                anthropicHasStoredKey = false
                                anthropicKeyMarkedForDeletion = true
                            }
                            .buttonStyle(.plain)
                            .font(.app(.satoshiMedium, size: 11))
                        }
                    }

                    Toggle("Enable Google Gemini", isOn: $enableGemini)
                        .font(.app(.satoshiMedium, size: 12))

                if enableGemini {
                    TextField("Google Cloud Project ID", text: $googleProjectID)
                        .textFieldStyle(.roundedBorder)

                    TextField("Billing Account ID", text: $googleBillingAccountID)
                            .textFieldStyle(.roundedBorder)

                        TextEditor(text: $googleServiceAccountJSON)
                            .font(.app(.satoshiMedium, size: 12))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                        if googleHasStoredCredentials && googleServiceAccountJSON.isEmpty {
                            Text("Service account stored in Keychain")
                                .font(.app(.satoshiMedium, size: 11))
                                .foregroundStyle(.secondary)
                        }
                        if googleHasStoredCredentials {
                            Button("Remove stored credentials") {
                                googleServiceAccountJSON = ""
                                googleHasStoredCredentials = false
                                googleCredentialsMarkedForDeletion = true
                            }
                            .buttonStyle(.plain)
                            .font(.app(.satoshiMedium, size: 11))
                        }
                    }
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Automation")
                    .font(.app(.satoshiBold, size: 14))
                Button("Import Cursor Session Cookie") {
                    Task {
                        do {
                            let cookie = try CursorCredentialExtractor().extractSessionCookie()
                            if let me = try? await cursorService.fetchMe(cookieHeader: cookie) {
                                try? await storage.saveCredentials(me)
                                session.credentials = me
                                automationMessage = "Imported cookie for \(me.email)"
                            } else {
                                automationMessage = "Unable to validate session cookie"
                            }
                        } catch {
                            automationMessage = "\(error.localizedDescription)"
                        }
                    }
                }
                .buttonStyle(.vibe(Color(hex: "5B67E2").opacity(0.6)))
                if automationMessage.isEmpty == false {
                    Text(automationMessage)
                        .font(.app(.satoshiMedium, size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Advanced")
                    .font(.app(.satoshiBold, size: 14))

                Toggle("Auto-detect timezone and locale", isOn: $autoDetectPreferences)
                    .font(.app(.satoshiMedium, size: 12))

                Toggle("Enable diagnostics logging", isOn: $enableDiagnosticsLogging)
                    .font(.app(.satoshiMedium, size: 12))

                Toggle("Show dock badge for alerts", isOn: $showAlertBadge)
                    .font(.app(.satoshiMedium, size: 12))

                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Log retention (days)")
                            .font(.app(.satoshiMedium, size: 11))
                        TextField("14", text: $logRetentionDays)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: logRetentionDays) { _, newValue in
                                logRetentionDays = filterIntegerInput(newValue)
                            }
                    }

                    VStack(alignment: .leading) {
                        Text("Notification threshold (0-1)")
                            .font(.app(.satoshiMedium, size: 11))
                        TextField("0.80", text: $notificationThresholdPercent)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                Toggle("Enable proxy ingestion server", isOn: $enableProxyIngestion)
                    .font(.app(.satoshiMedium, size: 12))

                if enableProxyIngestion {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Proxy port")
                                .font(.app(.satoshiMedium, size: 11))
                            TextField("7788", text: $proxyPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: proxyPort) { _, newValue in
                                    proxyPort = filterIntegerInput(newValue)
                                }
                        }

                        VStack(alignment: .leading) {
                            Text("Status export path")
                                .font(.app(.satoshiMedium, size: 11))
                            TextField("~/Library/Application Support/AIUsageTracker/status.json", text: $statusExportPath)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Toggle("Enable WebSocket bridge", isOn: $enableDeveloperWebSocket)
                    .font(.app(.satoshiMedium, size: 12))

                if enableDeveloperWebSocket {
                    VStack(alignment: .leading) {
                        Text("WebSocket port")
                            .font(.app(.satoshiMedium, size: 11))
                        TextField("8790", text: $developerWebSocketPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: developerWebSocketPort) { _, newValue in
                                developerWebSocketPort = filterIntegerInput(newValue)
                            }
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.vibe(Color(hex: "F58283").opacity(0.8)))
                
                // 清空 AppSession 按钮
                Button("Clear App Cache") {
                    showingClearSessionAlert = true
                }
                .buttonStyle(.vibe(.secondary.opacity(0.8)))
                .font(.app(.satoshiMedium, size: 12))
                
                
                Button("Save") {
                    Task { @MainActor in
                        saveSettings()
                        // Persist settings then close window
                        try? await self.appSettings.save(using: self.storage)
                        NSApplication.shared.keyWindow?.close()
                    }
                }
                .buttonStyle(.vibe(Color(hex: "5B67E2").opacity(0.8)))
            }
        }
        .padding(20)
        .frame(width: 520, height: 620)
        .onAppear {
            loadSettings()
        }
        .task { 
            try? await self.appSettings.save(using: self.storage) 
        }
        .alert("Clear App Session", isPresented: $showingClearSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task { @MainActor in
                    await clearAppSession()
                }
            }
        } message: {
            Text("This will clear all stored credentials and dashboard data. You will need to log in again.")
        }
    }
    
    private func loadSettings() {
        refreshFrequency = String(appSettings.overview.refreshInterval)
        usageHistoryLimit = String(appSettings.usageHistory.limit)
        pauseOnScreenSleep = appSettings.pauseOnScreenSleep
        launchAtLogin = launchAtLoginService.isEnabled
        appearanceSelection = appSettings.appearance
        analyticsDataDays = String(appSettings.analyticsDataDays)
        enableOpenAI = appSettings.providerSettings.enableOpenAI
        openAIAPIKey = ""
        openAIHasStoredKey = (try? secureStore.containsSecret(for: .openAIAPIKey)) ?? false
        openAIKeyMarkedForDeletion = false
        openAIOrganization = appSettings.providerSettings.openAIOrganization ?? ""
        enableAnthropic = appSettings.providerSettings.enableAnthropic
        anthropicAPIKey = ""
        anthropicHasStoredKey = (try? secureStore.containsSecret(for: .anthropicAPIKey)) ?? false
        anthropicKeyMarkedForDeletion = false
        enableGemini = appSettings.providerSettings.enableGoogleGemini
        googleServiceAccountJSON = ""
        googleHasStoredCredentials = (try? secureStore.containsSecret(for: .googleServiceAccount)) ?? false
        googleCredentialsMarkedForDeletion = false
        googleProjectID = appSettings.providerSettings.googleProjectID
        googleBillingAccountID = appSettings.providerSettings.googleBillingAccountID
        logRetentionDays = String(appSettings.advanced.logRetentionDays)
        enableProxyIngestion = appSettings.advanced.enableProxyIngestion
        proxyPort = String(appSettings.advanced.proxyPort)
        statusExportPath = appSettings.advanced.statusExportPath
        notificationThresholdPercent = String(format: "%.2f", appSettings.advanced.notificationThresholdPercent)
        autoDetectPreferences = appSettings.advanced.autoDetectPreferences
        enableDeveloperWebSocket = appSettings.advanced.enableDeveloperWebSocket
        developerWebSocketPort = String(appSettings.advanced.developerWebSocketPort)
        enableDiagnosticsLogging = appSettings.advanced.enableDiagnosticsLogging
        showAlertBadge = appSettings.advanced.showAlertBadge
    }

    private func saveSettings() {
        if let refreshValue = Int(refreshFrequency) {
            appSettings.overview.refreshInterval = refreshValue
        }
        
        if let limitValue = Int(usageHistoryLimit) {
            appSettings.usageHistory.limit = limitValue
        }
        
        appSettings.pauseOnScreenSleep = pauseOnScreenSleep

        _ = launchAtLoginService.setEnabled(launchAtLogin)
        appSettings.launchAtLogin = launchAtLogin
        appSettings.appearance = appearanceSelection
        appSettings.analyticsDataDays = Int(analyticsDataDays) ?? 7 // Default to 7 if invalid
        appSettings.providerSettings.enableOpenAI = enableOpenAI
        appSettings.providerSettings.openAIOrganization = openAIOrganization.isEmpty ? nil : openAIOrganization
        appSettings.providerSettings.enableAnthropic = enableAnthropic
        appSettings.providerSettings.enableGoogleGemini = enableGemini
        appSettings.providerSettings.googleProjectID = googleProjectID
        appSettings.providerSettings.googleBillingAccountID = googleBillingAccountID

        if openAIKeyMarkedForDeletion {
            try? secureStore.deleteSecret(for: .openAIAPIKey)
            appSettings.providerSettings.openAIKeyReference = nil
            openAIKeyMarkedForDeletion = false
        }
        if openAIAPIKey.isEmpty == false, let data = openAIAPIKey.data(using: .utf8) {
            try? secureStore.setSecret(data, for: .openAIAPIKey)
            appSettings.providerSettings.openAIKeyReference = .openAIAPIKey
            openAIAPIKey = ""
            openAIHasStoredKey = true
            openAIKeyMarkedForDeletion = false
        } else if ((try? secureStore.containsSecret(for: .openAIAPIKey)) ?? false) {
            appSettings.providerSettings.openAIKeyReference = .openAIAPIKey
        } else if !openAIKeyMarkedForDeletion {
            appSettings.providerSettings.openAIKeyReference = nil
        }

        if anthropicKeyMarkedForDeletion {
            try? secureStore.deleteSecret(for: .anthropicAPIKey)
            appSettings.providerSettings.anthropicKeyReference = nil
            anthropicKeyMarkedForDeletion = false
        }
        if anthropicAPIKey.isEmpty == false, let data = anthropicAPIKey.data(using: .utf8) {
            try? secureStore.setSecret(data, for: .anthropicAPIKey)
            appSettings.providerSettings.anthropicKeyReference = .anthropicAPIKey
            anthropicAPIKey = ""
            anthropicHasStoredKey = true
            anthropicKeyMarkedForDeletion = false
        } else if ((try? secureStore.containsSecret(for: .anthropicAPIKey)) ?? false) {
            appSettings.providerSettings.anthropicKeyReference = .anthropicAPIKey
        } else if !anthropicKeyMarkedForDeletion {
            appSettings.providerSettings.anthropicKeyReference = nil
        }

        if googleCredentialsMarkedForDeletion {
            try? secureStore.deleteSecret(for: .googleServiceAccount)
            appSettings.providerSettings.googleServiceAccountReference = nil
            googleCredentialsMarkedForDeletion = false
        }
        if googleServiceAccountJSON.isEmpty == false, let data = googleServiceAccountJSON.data(using: .utf8) {
            try? secureStore.setSecret(data, for: .googleServiceAccount)
            appSettings.providerSettings.googleServiceAccountReference = .googleServiceAccount
            googleServiceAccountJSON = ""
            googleHasStoredCredentials = true
            googleCredentialsMarkedForDeletion = false
        } else if ((try? secureStore.containsSecret(for: .googleServiceAccount)) ?? false) {
            appSettings.providerSettings.googleServiceAccountReference = .googleServiceAccount
        } else if !googleCredentialsMarkedForDeletion {
            appSettings.providerSettings.googleServiceAccountReference = nil
        }

        if let retention = Int(logRetentionDays) {
            appSettings.advanced.logRetentionDays = retention
        }
        appSettings.advanced.enableProxyIngestion = enableProxyIngestion
        if let proxy = Int(proxyPort) {
            appSettings.advanced.proxyPort = proxy
        }
        appSettings.advanced.statusExportPath = statusExportPath
        if let threshold = Double(notificationThresholdPercent) {
            appSettings.advanced.notificationThresholdPercent = threshold
        }
        appSettings.advanced.autoDetectPreferences = autoDetectPreferences
        appSettings.advanced.enableDeveloperWebSocket = enableDeveloperWebSocket
        if let wsPort = Int(developerWebSocketPort) {
            appSettings.advanced.developerWebSocketPort = wsPort
        }
        appSettings.advanced.enableDiagnosticsLogging = enableDiagnosticsLogging
        appSettings.advanced.showAlertBadge = showAlertBadge
    }
    
    private func clearAppSession() async {
        // 清空存储的 AppSession 数据
        await storage.clearAppSession()
        
        // 重置内存中的 AppSession
        session.credentials = nil
        session.snapshot = nil
        
        // 关闭设置窗口
        NSApplication.shared.keyWindow?.close()
    }
    
    /// 过滤输入，仅允许整数（0-9）
    private func filterIntegerInput(_ input: String) -> String {
        input.filter { $0.isNumber }
    }
}
