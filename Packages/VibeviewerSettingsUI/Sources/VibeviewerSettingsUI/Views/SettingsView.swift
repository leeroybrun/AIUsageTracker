import Observation
import SwiftUI
import VibeviewerAppEnvironment
import VibeviewerModel
import VibeviewerShareUI

public struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.cursorStorage) private var storage
    @Environment(\.launchAtLoginService) private var launchAtLoginService
    @Environment(AppSession.self) private var session
    
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
    @State private var enableAnthropic: Bool = false
    @State private var anthropicAPIKey: String = ""
    @State private var enableGemini: Bool = false
    @State private var googleServiceAccountJSON: String = ""
    @State private var googleProjectID: String = ""
    @State private var googleBillingAccountID: String = ""

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

                    Toggle("Enable OpenAI", isOn: $enableOpenAI)
                        .font(.app(.satoshiMedium, size: 12))

                    if enableOpenAI {
                        SecureField("OpenAI API Key", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)

                        TextField("OpenAI Organization (optional)", text: $openAIOrganization)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Enable Anthropic", isOn: $enableAnthropic)
                        .font(.app(.satoshiMedium, size: 12))

                    if enableAnthropic {
                        SecureField("Anthropic API Key", text: $anthropicAPIKey)
                            .textFieldStyle(.roundedBorder)
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
        openAIAPIKey = appSettings.providerSettings.openAIAPIKey
        openAIOrganization = appSettings.providerSettings.openAIOrganization ?? ""
        enableAnthropic = appSettings.providerSettings.enableAnthropic
        anthropicAPIKey = appSettings.providerSettings.anthropicAPIKey
        enableGemini = appSettings.providerSettings.enableGoogleGemini
        googleServiceAccountJSON = appSettings.providerSettings.googleServiceAccountJSON
        googleProjectID = appSettings.providerSettings.googleProjectID
        googleBillingAccountID = appSettings.providerSettings.googleBillingAccountID
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
        appSettings.providerSettings.openAIAPIKey = openAIAPIKey
        appSettings.providerSettings.openAIOrganization = openAIOrganization.isEmpty ? nil : openAIOrganization
        appSettings.providerSettings.enableAnthropic = enableAnthropic
        appSettings.providerSettings.anthropicAPIKey = anthropicAPIKey
        appSettings.providerSettings.enableGoogleGemini = enableGemini
        appSettings.providerSettings.googleServiceAccountJSON = googleServiceAccountJSON
        appSettings.providerSettings.googleProjectID = googleProjectID
        appSettings.providerSettings.googleBillingAccountID = googleBillingAccountID
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
