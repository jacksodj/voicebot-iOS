import UIKit
import PushKit
import CallKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var voiceManager: VoiceAgentManager?
    var callKitProvider: VoiceCallProvider?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize Voice Agent Manager
        voiceManager = VoiceAgentManager.shared

        // Initialize CallKit Provider
        callKitProvider = VoiceCallProvider()

        // Register for VoIP push notifications
        registerForVoIPPushes()

        // Configure audio session
        configureAudioSession()

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - Quick Actions

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleQuickAction(shortcutItem: shortcutItem, completionHandler: completionHandler)
    }

    private func handleQuickAction(shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type.hasSuffix("StartVoiceAgent") {
            // Start voice agent conversation
            voiceManager?.startConversation()
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    // MARK: - VoIP Push Registration

    private func registerForVoIPPushes() {
        let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}

// MARK: - PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }

        let deviceToken = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("VoIP device token: \(deviceToken)")

        // TODO: Send device token to your backend server
        // This token should be sent to your notification service for triggering calls
        NotificationCenter.default.post(name: .voipTokenReceived, object: deviceToken)
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        print("Received VoIP push: \(payload.dictionaryPayload)")

        // Extract call information from payload
        let callerName = payload.dictionaryPayload["caller"] as? String ?? "Voice Assistant"
        let context = payload.dictionaryPayload["context"] as? String

        // Report incoming call to CallKit
        callKitProvider?.reportIncomingCall(caller: callerName, context: context) { error in
            if let error = error {
                print("Failed to report incoming call: \(error.localizedDescription)")
            }
            completion()
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("VoIP push token invalidated")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let voipTokenReceived = Notification.Name("voipTokenReceived")
    static let callAnswered = Notification.Name("callAnswered")
    static let callEnded = Notification.Name("callEnded")
}
