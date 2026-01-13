import Foundation
import AVFoundation

/// Protocol for audio engine events
protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didCaptureAudio audioData: Data)
    func audioEngineDidStartCapture(_ engine: AudioEngine)
    func audioEngineDidStopCapture(_ engine: AudioEngine)
    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error)
}

/// Audio engine for capturing and playing audio using AVAudioEngine
class AudioEngine: NSObject {

    // MARK: - Properties

    weak var delegate: AudioEngineDelegate?

    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let outputNode: AVAudioOutputNode
    private let playerNode = AVAudioPlayerNode()

    private var audioFormat: AVAudioFormat?
    private var isCapturing = false

    // Audio configuration
    private let sampleRate: Double = 16000 // 16kHz for speech recognition
    private let channelCount: AVAudioChannelCount = 1 // Mono

    // MARK: - Initialization

    override init() {
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        super.init()

        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Attach player node
        audioEngine.attach(playerNode)

        // Get the input format
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Create desired format (16kHz, mono, PCM)
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        ) else {
            print("Failed to create desired audio format")
            return
        }

        audioFormat = desiredFormat

        // Connect player node to output
        audioEngine.connect(playerNode, to: outputNode, format: desiredFormat)

        print("Audio engine configured: \(sampleRate)Hz, \(channelCount) channel(s)")
    }

    // MARK: - Recording

    func startCapture() {
        guard !isCapturing else {
            print("Audio capture already started")
            return
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)

            // Install tap on input node
            let inputFormat = inputNode.inputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                self.processAudioBuffer(buffer)
            }

            // Start audio engine
            try audioEngine.start()
            isCapturing = true

            print("Audio capture started")
            delegate?.audioEngineDidStartCapture(self)

        } catch {
            print("Failed to start audio capture: \(error.localizedDescription)")
            delegate?.audioEngine(self, didEncounterError: error)
        }
    }

    func stopCapture() {
        guard isCapturing else {
            print("Audio capture not running")
            return
        }

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false

        print("Audio capture stopped")
        delegate?.audioEngineDidStopCapture(self)
    }

    // MARK: - Playback

    func playAudio(data: Data) {
        guard let audioFormat = audioFormat else {
            print("Audio format not initialized")
            return
        }

        do {
            // Convert Data to AVAudioPCMBuffer
            let frameCount = UInt32(data.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
                print("Failed to create audio buffer")
                return
            }

            buffer.frameLength = frameCount

            // Copy data to buffer
            data.withUnsafeBytes { rawBufferPointer in
                guard let address = rawBufferPointer.baseAddress else { return }
                buffer.int16ChannelData?.pointee.update(from: address.assumingMemoryBound(to: Int16.self), count: Int(frameCount))
            }

            // Schedule and play buffer
            if !playerNode.isPlaying {
                playerNode.play()
            }

            playerNode.scheduleBuffer(buffer, completionHandler: nil)

        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            delegate?.audioEngine(self, didEncounterError: error)
        }
    }

    func stopPlayback() {
        playerNode.stop()
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        let channelDataPointer = channelData.pointee

        // Convert to Data
        let data = Data(bytes: channelDataPointer, count: frameLength * MemoryLayout<Int16>.size)

        // Send to delegate
        delegate?.audioEngine(self, didCaptureAudio: data)
    }

    // MARK: - Cleanup

    deinit {
        if isCapturing {
            stopCapture()
        }
    }
}

// MARK: - Audio Session Manager

class AudioSessionManager {

    static let shared = AudioSessionManager()

    private init() {}

    func configureForVoiceCall() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("Audio session configured for voice call")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func deactivate() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
