import Foundation

/// Centralized settings manager for all app configuration
class SettingsManager {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let serverPreset = "serverPreset"
        static let customServerURL = "customServerURL"
        static let sampleRate = "sampleRate"
        static let audioChannels = "audioChannels"
        static let connectionTimeout = "connectionTimeout"
        static let maxReconnectAttempts = "maxReconnectAttempts"
        static let debugLoggingEnabled = "debugLoggingEnabled"
        static let autoReconnect = "autoReconnect"
        static let callKitEnabled = "callKitEnabled"
        static let quickActionsEnabled = "quickActionsEnabled"
        static let audioOutputMode = "audioOutputMode"
    }

    // MARK: - Server Presets

    enum ServerPreset: String, CaseIterable {
        case tailscale = "tailscale"
        case local = "local"
        case production = "production"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .tailscale: return "Tailscale (DGX Spark)"
            case .local: return "Local Development"
            case .production: return "Production"
            case .custom: return "Custom URL"
            }
        }

        var defaultURL: String? {
            switch self {
            case .tailscale: return "ws://dgx-spark.tail-scale.ts.net:8080"
            case .local: return "ws://localhost:8080"
            case .production: return "wss://dgx-spark.yourdomain.com:8080"
            case .custom: return nil
            }
        }
    }

    // MARK: - Audio Output Mode

    enum AudioOutputMode: String, CaseIterable {
        case speaker = "speaker"
        case receiver = "receiver"
        case automatic = "automatic"

        var displayName: String {
            switch self {
            case .speaker: return "Speaker"
            case .receiver: return "Receiver (Earpiece)"
            case .automatic: return "Automatic"
            }
        }
    }

    // MARK: - Sample Rate Options

    enum SampleRate: Int, CaseIterable {
        case rate8kHz = 8000
        case rate16kHz = 16000
        case rate22kHz = 22050
        case rate44kHz = 44100

        var displayName: String {
            switch self {
            case .rate8kHz: return "8 kHz (Low quality)"
            case .rate16kHz: return "16 kHz (Speech optimized)"
            case .rate22kHz: return "22 kHz (Standard)"
            case .rate44kHz: return "44.1 kHz (High quality)"
            }
        }
    }

    // MARK: - Default Values

    private enum Defaults {
        static let serverPreset: ServerPreset = .tailscale
        static let sampleRate = 16000
        static let audioChannels = 1
        static let connectionTimeout = 30
        static let maxReconnectAttempts = 5
        static let debugLoggingEnabled = true
        static let autoReconnect = true
        static let callKitEnabled = true
        static let quickActionsEnabled = true
        static let audioOutputMode: AudioOutputMode = .speaker
    }

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    /// Notification posted when settings change
    static let settingsDidChangeNotification = Notification.Name("SettingsManagerDidChange")

    // MARK: - Server Settings

    var serverPreset: ServerPreset {
        get {
            if let rawValue = defaults.string(forKey: Keys.serverPreset),
               let preset = ServerPreset(rawValue: rawValue) {
                return preset
            }
            return Defaults.serverPreset
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.serverPreset)
            notifySettingsChanged()
        }
    }

    var customServerURL: String {
        get {
            return defaults.string(forKey: Keys.customServerURL) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Keys.customServerURL)
            notifySettingsChanged()
        }
    }

    /// Returns the active server URL based on preset selection
    var serverURL: String {
        get {
            if serverPreset == .custom {
                return customServerURL.isEmpty ? ServerPreset.tailscale.defaultURL! : customServerURL
            }
            return serverPreset.defaultURL ?? ServerPreset.tailscale.defaultURL!
        }
        set {
            // When setting a URL directly, determine if it matches a preset
            for preset in ServerPreset.allCases where preset != .custom {
                if preset.defaultURL == newValue {
                    serverPreset = preset
                    return
                }
            }
            // If no match, set as custom
            serverPreset = .custom
            customServerURL = newValue
        }
    }

    // MARK: - Audio Settings

    var sampleRate: Int {
        get {
            let value = defaults.integer(forKey: Keys.sampleRate)
            return value > 0 ? value : Defaults.sampleRate
        }
        set {
            defaults.set(newValue, forKey: Keys.sampleRate)
            notifySettingsChanged()
        }
    }

    var audioChannels: Int {
        get {
            let value = defaults.integer(forKey: Keys.audioChannels)
            return value > 0 ? value : Defaults.audioChannels
        }
        set {
            defaults.set(newValue, forKey: Keys.audioChannels)
            notifySettingsChanged()
        }
    }

    var audioOutputMode: AudioOutputMode {
        get {
            if let rawValue = defaults.string(forKey: Keys.audioOutputMode),
               let mode = AudioOutputMode(rawValue: rawValue) {
                return mode
            }
            return Defaults.audioOutputMode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.audioOutputMode)
            notifySettingsChanged()
        }
    }

    /// Formatted audio format string for display
    var audioFormatDescription: String {
        return "PCM 16-bit \(audioChannels == 1 ? "mono" : "stereo")"
    }

    // MARK: - Connection Settings

    var connectionTimeout: Int {
        get {
            let value = defaults.integer(forKey: Keys.connectionTimeout)
            return value > 0 ? value : Defaults.connectionTimeout
        }
        set {
            defaults.set(newValue, forKey: Keys.connectionTimeout)
            notifySettingsChanged()
        }
    }

    var maxReconnectAttempts: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxReconnectAttempts)
            return value > 0 ? value : Defaults.maxReconnectAttempts
        }
        set {
            defaults.set(newValue, forKey: Keys.maxReconnectAttempts)
            notifySettingsChanged()
        }
    }

    var autoReconnect: Bool {
        get {
            if defaults.object(forKey: Keys.autoReconnect) == nil {
                return Defaults.autoReconnect
            }
            return defaults.bool(forKey: Keys.autoReconnect)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoReconnect)
            notifySettingsChanged()
        }
    }

    // MARK: - Feature Flags

    var debugLoggingEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.debugLoggingEnabled) == nil {
                return Defaults.debugLoggingEnabled
            }
            return defaults.bool(forKey: Keys.debugLoggingEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.debugLoggingEnabled)
            notifySettingsChanged()
        }
    }

    var callKitEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.callKitEnabled) == nil {
                return Defaults.callKitEnabled
            }
            return defaults.bool(forKey: Keys.callKitEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.callKitEnabled)
            notifySettingsChanged()
        }
    }

    var quickActionsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.quickActionsEnabled) == nil {
                return Defaults.quickActionsEnabled
            }
            return defaults.bool(forKey: Keys.quickActionsEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.quickActionsEnabled)
            notifySettingsChanged()
        }
    }

    // MARK: - App Info

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Initialization

    private init() {
        // Migrate old serverURL key if it exists
        migrateOldSettings()
    }

    private func migrateOldSettings() {
        // Check if old serverURL key exists and migrate it
        if let oldServerURL = defaults.string(forKey: "serverURL"),
           defaults.object(forKey: Keys.serverPreset) == nil {
            // Determine preset from old URL
            for preset in ServerPreset.allCases where preset != .custom {
                if preset.defaultURL == oldServerURL {
                    serverPreset = preset
                    return
                }
            }
            // If not a preset, set as custom
            serverPreset = .custom
            customServerURL = oldServerURL
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        let allKeys = [
            Keys.serverURL,
            Keys.serverPreset,
            Keys.customServerURL,
            Keys.sampleRate,
            Keys.audioChannels,
            Keys.connectionTimeout,
            Keys.maxReconnectAttempts,
            Keys.debugLoggingEnabled,
            Keys.autoReconnect,
            Keys.callKitEnabled,
            Keys.quickActionsEnabled,
            Keys.audioOutputMode
        ]

        allKeys.forEach { defaults.removeObject(forKey: $0) }
        notifySettingsChanged()
    }

    // MARK: - Export/Import

    func exportSettings() -> [String: Any] {
        return [
            Keys.serverPreset: serverPreset.rawValue,
            Keys.customServerURL: customServerURL,
            Keys.sampleRate: sampleRate,
            Keys.audioChannels: audioChannels,
            Keys.connectionTimeout: connectionTimeout,
            Keys.maxReconnectAttempts: maxReconnectAttempts,
            Keys.debugLoggingEnabled: debugLoggingEnabled,
            Keys.autoReconnect: autoReconnect,
            Keys.callKitEnabled: callKitEnabled,
            Keys.quickActionsEnabled: quickActionsEnabled,
            Keys.audioOutputMode: audioOutputMode.rawValue
        ]
    }

    func importSettings(_ settings: [String: Any]) {
        if let preset = settings[Keys.serverPreset] as? String,
           let serverPresetValue = ServerPreset(rawValue: preset) {
            serverPreset = serverPresetValue
        }

        if let customURL = settings[Keys.customServerURL] as? String {
            customServerURL = customURL
        }

        if let rate = settings[Keys.sampleRate] as? Int {
            sampleRate = rate
        }

        if let channels = settings[Keys.audioChannels] as? Int {
            audioChannels = channels
        }

        if let timeout = settings[Keys.connectionTimeout] as? Int {
            connectionTimeout = timeout
        }

        if let attempts = settings[Keys.maxReconnectAttempts] as? Int {
            maxReconnectAttempts = attempts
        }

        if let debug = settings[Keys.debugLoggingEnabled] as? Bool {
            debugLoggingEnabled = debug
        }

        if let reconnect = settings[Keys.autoReconnect] as? Bool {
            autoReconnect = reconnect
        }

        if let callKit = settings[Keys.callKitEnabled] as? Bool {
            callKitEnabled = callKit
        }

        if let quickActions = settings[Keys.quickActionsEnabled] as? Bool {
            quickActionsEnabled = quickActions
        }

        if let outputMode = settings[Keys.audioOutputMode] as? String,
           let mode = AudioOutputMode(rawValue: outputMode) {
            audioOutputMode = mode
        }

        notifySettingsChanged()
    }

    // MARK: - Notifications

    private func notifySettingsChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.settingsDidChangeNotification, object: nil)
        }
    }

    // MARK: - Debug Logging

    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard debugLoggingEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        print("[\(filename):\(line)] \(function): \(message)")
    }
}
