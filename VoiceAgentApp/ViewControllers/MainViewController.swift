import UIKit

class MainViewController: UIViewController {

    // MARK: - UI Components

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Voice Agent Ready"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Disconnected"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Conversation", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Stop Conversation", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.isEnabled = false
        button.alpha = 0.5
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let transcriptionTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let settingsButton: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: nil,
            action: nil
        )
    }()

    // MARK: - Properties

    private let voiceManager = VoiceAgentManager.shared
    private var transcriptionText = ""

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupActions()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Voice Agent"
        view.backgroundColor = .systemBackground

        // Add navigation bar button
        settingsButton.target = self
        settingsButton.action = #selector(settingsTapped)
        navigationItem.rightBarButtonItem = settingsButton

        // Add subviews
        view.addSubview(statusLabel)
        view.addSubview(connectionStatusLabel)
        view.addSubview(startButton)
        view.addSubview(stopButton)
        view.addSubview(transcriptionTextView)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Connection Status Label
            connectionStatusLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            connectionStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            connectionStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Start Button
            startButton.topAnchor.constraint(equalTo: connectionStatusLabel.bottomAnchor, constant: 40),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            startButton.heightAnchor.constraint(equalToConstant: 50),

            // Stop Button
            stopButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 20),
            stopButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stopButton.heightAnchor.constraint(equalToConstant: 50),

            // Transcription Text View
            transcriptionTextView.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 30),
            transcriptionTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transcriptionTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            transcriptionTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupActions() {
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscription(_:)),
            name: NSNotification.Name("TranscriptionReceived"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAgentResponse(_:)),
            name: NSNotification.Name("AgentResponseReceived"),
            object: nil
        )
    }

    // MARK: - Actions

    @objc private func startButtonTapped() {
        startVoiceConversation()
    }

    @objc private func stopButtonTapped() {
        voiceManager.stopConversation()
        updateUIForState(isActive: false)
    }

    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    // MARK: - Public Methods

    func startVoiceConversation() {
        voiceManager.startConversation()
        updateUIForState(isActive: true)
    }

    // MARK: - UI Updates

    private func updateUIForState(isActive: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.startButton.isEnabled = !isActive
            self.startButton.alpha = isActive ? 0.5 : 1.0

            self.stopButton.isEnabled = isActive
            self.stopButton.alpha = isActive ? 1.0 : 0.5

            self.statusLabel.text = isActive ? "🎙️ Listening..." : "Voice Agent Ready"
            self.connectionStatusLabel.text = isActive ? "Connected" : "Disconnected"
            self.connectionStatusLabel.textColor = isActive ? .systemGreen : .systemRed
        }
    }

    @objc private func handleTranscription(_ notification: Notification) {
        guard let transcript = notification.object as? String else { return }

        DispatchQueue.main.async {
            self.transcriptionText += "You: \(transcript)\n\n"
            self.transcriptionTextView.text = self.transcriptionText

            // Scroll to bottom
            let range = NSMakeRange(self.transcriptionText.count - 1, 1)
            self.transcriptionTextView.scrollRangeToVisible(range)
        }
    }

    @objc private func handleAgentResponse(_ notification: Notification) {
        guard let response = notification.object as? String else { return }

        DispatchQueue.main.async {
            self.transcriptionText += "Agent: \(response)\n\n"
            self.transcriptionTextView.text = self.transcriptionText

            // Scroll to bottom
            let range = NSMakeRange(self.transcriptionText.count - 1, 1)
            self.transcriptionTextView.scrollRangeToVisible(range)
        }
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
