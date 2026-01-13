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
    private var serverURL: String

    // Configuration
    struct Configuration {
        // Default to Tailscale URL for DGX Spark
        static let defaultServerURL = "ws://dgx-spark.tail-scale.ts.net:8080"

        // Alternative configurations
        static let localServerURL = "ws://localhost:8080"
        static let productionServerURL = "wss://dgx-spark.yourdomain.com:8080"
    }

    // MARK: - Initialization

    private override init() {
        // Load server URL from UserDefaults or use default
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? Configuration.defaultServerURL
        super.init()

        setupComponents()
        setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupComponents() {
        // Initialize WebSocket client
        webSocketClient = WebSocketClient(serverURL: serverURL)
        webSocketClient?.delegate = self

        // Initialize audio engine
        audioEngine = AudioEngine()
        audioEngine?.delegate = self

        // Initialize CallKit provider
        callProvider = VoiceCallProvider()
        callProvider?.setCallAnsweredHandler { [weak self] uuid in
            print("Call answered: \(uuid)")
            self?.handleCallAnswered()
        }
        callProvider?.setCallEndedHandler { [weak self] uuid in
            print("Call ended: \(uuid)")
            self?.handleCallEnded()
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
    }

    // MARK: - Public API

    func startConversation() {
        guard !isConversationActive else {
            print("Conversation already active")
            return
        }

        print("Starting voice conversation")

        // Connect to WebSocket
        webSocketClient?.connect()

        // Start audio capture
        audioEngine?.startCapture()

        isConversationActive = true
    }

    func stopConversation() {
        guard isConversationActive else {
            print("No active conversation to stop")
            return
        }

        print("Stopping voice conversation")

        // Stop audio capture
        audioEngine?.stopCapture()
        audioEngine?.stopPlayback()

        // Disconnect WebSocket
        webSocketClient?.disconnect()

        isConversationActive = false
    }

    func updateServerURL(_ url: String) {
        self.serverURL = url
        UserDefaults.standard.set(url, forKey: "serverURL")

        // Reinitialize WebSocket client with new URL
        webSocketClient?.disconnect()
        webSocketClient = WebSocketClient(serverURL: url)
        webSocketClient?.delegate = self
    }

    // MARK: - Call Handling

    @objc private func handleCallAnswered() {
        print("Voice agent call answered")
        startConversation()
    }

    @objc private func handleCallEnded() {
        print("Voice agent call ended")
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
            print("Failed to serialize message")
            return
        }

        webSocketClient?.send(text: jsonString) { error in
            if let error = error {
                print("Failed to send text message: \(error.localizedDescription)")
            } else {
                print("Text message sent successfully")
            }
        }
    }
}

// MARK: - WebSocketClientDelegate

extension VoiceAgentManager: WebSocketClientDelegate {

    func webSocketDidConnect(_ client: WebSocketClient) {
        print("VoiceAgentManager: WebSocket connected")

        // Send initial configuration message
        let configMessage: [String: Any] = [
            "type": "config",
            "sampleRate": 16000,
            "channels": 1,
            "encoding": "pcm_s16le"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: configMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            client.send(text: jsonString) { error in
                if let error = error {
                    print("Failed to send config: \(error.localizedDescription)")
                }
            }
        }
    }

    func webSocketDidDisconnect(_ client: WebSocketClient, error: Error?) {
        print("VoiceAgentManager: WebSocket disconnected")
        if let error = error {
            print("Disconnection error: \(error.localizedDescription)")
        }

        // Stop audio if connection lost
        if isConversationActive {
            audioEngine?.stopCapture()
        }
    }

    func webSocketDidReceiveData(_ client: WebSocketClient, data: Data) {
        print("VoiceAgentManager: Received audio data (\(data.count) bytes)")

        // Play received audio through audio engine
        audioEngine?.playAudio(data: data)
    }

    func webSocketDidReceiveText(_ client: WebSocketClient, text: String) {
        print("VoiceAgentManager: Received text: \(text)")

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
                print("Transcription: \(transcript)")
                // Notify UI or process transcription
                NotificationCenter.default.post(
                    name: NSNotification.Name("TranscriptionReceived"),
                    object: transcript
                )
            }

        case "response":
            if let responseText = message["text"] as? String {
                print("Agent response: \(responseText)")
                // Notify UI
                NotificationCenter.default.post(
                    name: NSNotification.Name("AgentResponseReceived"),
                    object: responseText
                )
            }

        case "error":
            if let errorMessage = message["message"] as? String {
                print("Server error: \(errorMessage)")
            }

        default:
            print("Unknown message type: \(type)")
        }
    }
}

// MARK: - AudioEngineDelegate

extension VoiceAgentManager: AudioEngineDelegate {

    func audioEngine(_ engine: AudioEngine, didCaptureAudio audioData: Data) {
        // Send audio data to server via WebSocket
        webSocketClient?.send(data: audioData) { error in
            if let error = error {
                print("Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }

    func audioEngineDidStartCapture(_ engine: AudioEngine) {
        print("VoiceAgentManager: Audio capture started")
    }

    func audioEngineDidStopCapture(_ engine: AudioEngine) {
        print("VoiceAgentManager: Audio capture stopped")
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error) {
        print("VoiceAgentManager: Audio engine error: \(error.localizedDescription)")
    }
}
