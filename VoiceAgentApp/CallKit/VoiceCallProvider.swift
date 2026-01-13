import Foundation
import CallKit
import AVFoundation

/// CallKit provider for handling incoming voice agent calls
class VoiceCallProvider: NSObject {

    // MARK: - Properties

    private let provider: CXProvider
    private let callController = CXCallController()
    private var currentCallUUID: UUID?
    private var onCallAnswered: ((UUID) -> Void)?
    private var onCallEnded: ((UUID) -> Void)?

    // MARK: - Initialization

    override init() {
        // Configure provider
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.localizedName = "Voice Agent"

        // Set ringtone (optional)
        if let ringtonePath = Bundle.main.path(forResource: "ringtone", ofType: "caf") {
            configuration.ringtoneSound = ringtonePath
        }

        // Create provider
        provider = CXProvider(configuration: configuration)

        super.init()

        // Set delegate
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Incoming Call Reporting

    func reportIncomingCall(caller: String, context: String?, completion: @escaping (Error?) -> Void) {
        let callUUID = UUID()
        currentCallUUID = callUUID

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.hasVideo = false
        update.localizedCallerName = caller
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        provider.reportNewIncomingCall(with: callUUID, update: update) { error in
            if let error = error {
                print("Failed to report incoming call: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Incoming call reported successfully: \(callUUID)")
                completion(nil)
            }
        }
    }

    // MARK: - Outgoing Call

    func startOutgoingCall(to recipient: String, completion: @escaping (Error?) -> Void) {
        let callUUID = UUID()
        currentCallUUID = callUUID

        let handle = CXHandle(type: .generic, value: recipient)
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        startCallAction.isVideo = false

        let transaction = CXTransaction(action: startCallAction)

        callController.request(transaction) { error in
            if let error = error {
                print("Failed to start outgoing call: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Outgoing call started: \(callUUID)")
                completion(nil)
            }
        }
    }

    // MARK: - Call Management

    func endCall(uuid: UUID? = nil) {
        let callUUID = uuid ?? currentCallUUID
        guard let callUUID = callUUID else {
            print("No active call to end")
            return
        }

        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)

        callController.request(transaction) { error in
            if let error = error {
                print("Failed to end call: \(error.localizedDescription)")
            } else {
                print("Call ended: \(callUUID)")
            }
        }
    }

    func reportCallConnected(uuid: UUID? = nil) {
        let callUUID = uuid ?? currentCallUUID
        guard let callUUID = callUUID else { return }

        provider.reportOutgoingCall(with: callUUID, connectedAt: Date())
    }

    func reportCallFailed(uuid: UUID? = nil) {
        let callUUID = uuid ?? currentCallUUID
        guard let callUUID = callUUID else { return }

        provider.reportCall(with: callUUID, endedAt: Date(), reason: .failed)
        currentCallUUID = nil
    }

    // MARK: - Callbacks

    func setCallAnsweredHandler(_ handler: @escaping (UUID) -> Void) {
        onCallAnswered = handler
    }

    func setCallEndedHandler(_ handler: @escaping (UUID) -> Void) {
        onCallEnded = handler
    }
}

// MARK: - CXProviderDelegate

extension VoiceCallProvider: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        print("Provider did reset")
        currentCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("Provider perform start call action")

        // Configure audio session
        configureAudioSession()

        // Report call connected
        provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())

        // Fulfill action
        action.fulfill()

        // Notify that call was answered
        onCallAnswered?(action.callUUID)
        NotificationCenter.default.post(name: .callAnswered, object: action.callUUID)
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("Provider perform answer call action")

        // Configure audio session
        configureAudioSession()

        // Fulfill action
        action.fulfill()

        // Notify that call was answered
        onCallAnswered?(action.callUUID)
        NotificationCenter.default.post(name: .callAnswered, object: action.callUUID)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("Provider perform end call action")

        // Fulfill action
        action.fulfill()

        // Notify that call ended
        onCallEnded?(action.callUUID)
        NotificationCenter.default.post(name: .callEnded, object: action.callUUID)

        // Clear current call
        if currentCallUUID == action.callUUID {
            currentCallUUID = nil
        }
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("Provider perform set held call action")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("Provider perform set muted call action: \(action.isMuted)")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("Provider did activate audio session")
        // Audio session is now active, start audio processing
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("Provider did deactivate audio session")
        // Audio session deactivated, stop audio processing
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        AudioSessionManager.shared.configureForVoiceCall()
    }
}
