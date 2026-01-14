import Foundation
import AVFoundation

/// Main coordinator for voice agent functionality
class VoiceAgentManager: NSObject {

    // MARK: - Singleton

    static let shared = VoiceAgentManager()

    // MARK: - Properties

    private var webSocketClient: WebSocketClient?
    private var audioEngine: AudioEngine?
    private var callProvider: VoiceCallProvider?

    private var isConversationActive = false
    private let settings = SettingsManager.shared

    // MARK: - Initialization

    private override init() {
        super.init()

        setupComponents()
        setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupComponents() {
        // Initialize WebSocket client with settings
        webSocketClient = WebSocketClient(
            serverURL: settings.serverURL,
            timeout: settings.connectionTimeout,
            maxReconnectAttempts: settings.maxReconnectAttempts,
            autoReconnect: settings.autoReconnect
        )
        webSocketClient?.delegate = self

        // Initialize audio engine with settings
        audioEngine = AudioEngine(
            sampleRate: Double(settings.sampleRate),
            channels: UInt32(settings.audioChannels),
            outputMode: settings.audioOutputMode
        )
        audioEngine?.delegate = self

        // Initialize CallKit provider if enabled
        if settings.callKitEnabled {
            callProvider = VoiceCallProvider()
            callProvider?.setCallAnsweredHandler { [weak self] uuid in
                self?.log("Call answered: \(uuid)")
                self?.handleCallAnswered()
            }
            callProvider?.setCallEndedHandler { [weak self] uuid in
                self?.log("Call ended: \(uuid)")
                self?.handleCallEnded()
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallAnswered),
            name: .callAnswered,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallEnded),
            name: .callEnded,
            object: nil
        )

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleSettingsChanged() {
        log("Settings changed, reinitializing components if needed")

        // Only reinitialize if not in an active conversation
        guard !isConversationActive else {
            log("Conversation active, settings will apply on next connection")
            return
        }

        // Reinitialize WebSocket client with new settings
        webSocketClient?.disconnect()
        webSocketClient = WebSocketClient(
            serverURL: settings.serverURL,
            timeout: settings.connectionTimeout,
            maxReconnectAttempts: settings.maxReconnectAttempts,
            autoReconnect: settings.autoReconnect
        )
        webSocketClient?.delegate = self

        // Reinitialize audio engine with new settings
        audioEngine = AudioEngine(
            sampleRate: Double(settings.sampleRate),
            channels: UInt32(settings.audioChannels),
            outputMode: settings.audioOutputMode
        )
        audioEngine?.delegate = self
    }

    // MARK: - Public API

    func startConversation() {
        guard !isConversationActive else {
            log("Conversation already active")
            return
        }

        log("Starting voice conversation")

        // Connect to WebSocket
        webSocketClient?.connect()

        // Start audio capture
        audioEngine?.startCapture()

        isConversationActive = true
    }

    func stopConversation() {
        guard isConversationActive else {
            log("No active conversation to stop")
            return
        }

        log("Stopping voice conversation")

        // Stop audio capture
        audioEngine?.stopCapture()
        audioEngine?.stopPlayback()

        // Disconnect WebSocket
        webSocketClient?.disconnect()

        isConversationActive = false
    }

    func updateServerURL(_ url: String) {
        settings.serverURL = url

        // Reinitialize WebSocket client with new URL if not in conversation
        if !isConversationActive {
            webSocketClient?.disconnect()
            webSocketClient = WebSocketClient(
                serverURL: url,
                timeout: settings.connectionTimeout,
                maxReconnectAttempts: settings.maxReconnectAttempts,
                autoReconnect: settings.autoReconnect
            )
            webSocketClient?.delegate = self
        }
    }

    // MARK: - Call Handling

    @objc private func handleCallAnswered() {
        log("Voice agent call answered")
        startConversation()
    }

    @objc private func handleCallEnded() {
        log("Voice agent call ended")
        stopConversation()
    }

    // MARK: - Message Sending

    func sendTextMessage(_ message: String) {
        let jsonMessage: [String: Any] = [
            "type": "text",
            "content": message,
            "timestamp": Date().timeIntervalSince1970
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            log("Failed to serialize message")
            return
        }

        webSocketClient?.send(text: jsonString) { [weak self] error in
            if let error = error {
                self?.log("Failed to send text message: \(error.localizedDescription)")
            } else {
                self?.log("Text message sent successfully")
            }
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        settings.log(message, file: #file, function: #function, line: #line)
    }
}

// MARK: - WebSocketClientDelegate

extension VoiceAgentManager: WebSocketClientDelegate {

    func webSocketDidConnect(_ client: WebSocketClient) {
        log("WebSocket connected")

        // Send initial configuration message using current settings
        let configMessage: [String: Any] = [
            "type": "config",
            "sampleRate": settings.sampleRate,
            "channels": settings.audioChannels,
            "encoding": "pcm_s16le"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: configMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            client.send(text: jsonString) { [weak self] error in
                if let error = error {
                    self?.log("Failed to send config: \(error.localizedDescription)")
                }
            }
        }
    }

    func webSocketDidDisconnect(_ client: WebSocketClient, error: Error?) {
        log("WebSocket disconnected")
        if let error = error {
            log("Disconnection error: \(error.localizedDescription)")
        }

        // Stop audio if connection lost
        if isConversationActive {
            audioEngine?.stopCapture()
        }
    }

    func webSocketDidReceiveData(_ client: WebSocketClient, data: Data) {
        log("Received audio data (\(data.count) bytes)")

        // Play received audio through audio engine
        audioEngine?.playAudio(data: data)
    }

    func webSocketDidReceiveText(_ client: WebSocketClient, text: String) {
        log("Received text: \(text)")

        // Parse and handle text messages (transcriptions, commands, etc.)
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            handleServerMessage(json)
        }
    }

    private func handleServerMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "transcription":
            if let transcript = message["text"] as? String {
                log("Transcription: \(transcript)")
                // Notify UI or process transcription
                NotificationCenter.default.post(
                    name: NSNotification.Name("TranscriptionReceived"),
                    object: transcript
                )
            }

        case "response":
            if let responseText = message["text"] as? String {
                log("Agent response: \(responseText)")
                // Notify UI
                NotificationCenter.default.post(
                    name: NSNotification.Name("AgentResponseReceived"),
                    object: responseText
                )
            }

        case "error":
            if let errorMessage = message["message"] as? String {
                log("Server error: \(errorMessage)")
            }

        default:
            log("Unknown message type: \(type)")
        }
    }
}

// MARK: - AudioEngineDelegate

extension VoiceAgentManager: AudioEngineDelegate {

    func audioEngine(_ engine: AudioEngine, didCaptureAudio audioData: Data) {
        // Send audio data to server via WebSocket
        webSocketClient?.send(data: audioData) { [weak self] error in
            if let error = error {
                self?.log("Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }

    func audioEngineDidStartCapture(_ engine: AudioEngine) {
        log("Audio capture started")
    }

    func audioEngineDidStopCapture(_ engine: AudioEngine) {
        log("Audio capture stopped")
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error) {
        log("Audio engine error: \(error.localizedDescription)")
    }
}
