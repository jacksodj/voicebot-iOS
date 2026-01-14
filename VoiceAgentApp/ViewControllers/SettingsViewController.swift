import UIKit

class SettingsViewController: UIViewController {

    // MARK: - UI Components

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    // MARK: - Properties

    private let settings = SettingsManager.shared

    private enum SettingsSection: Int, CaseIterable {
        case server
        case audio
        case connection
        case features
        case about

        var title: String {
            switch self {
            case .server: return "Server"
            case .audio: return "Audio"
            case .connection: return "Connection"
            case .features: return "Features"
            case .about: return "About"
            }
        }

        var footer: String? {
            switch self {
            case .server:
                return "Select a server preset or enter a custom WebSocket URL."
            case .audio:
                return "Audio settings affect voice quality and bandwidth usage."
            case .connection:
                return "Configure network timeout and reconnection behavior."
            case .features:
                return nil
            case .about:
                return nil
            }
        }
    }

    private enum SettingsRow {
        case serverPreset
        case customURL
        case testConnection
        case sampleRate
        case audioOutput
        case audioFormat
        case connectionTimeout
        case maxReconnectAttempts
        case autoReconnect
        case debugLogging
        case callKit
        case quickActions
        case version
        case documentation
        case resetSettings

        var title: String {
            switch self {
            case .serverPreset: return "Server"
            case .customURL: return "Custom URL"
            case .testConnection: return "Test Connection"
            case .sampleRate: return "Sample Rate"
            case .audioOutput: return "Audio Output"
            case .audioFormat: return "Audio Format"
            case .connectionTimeout: return "Connection Timeout"
            case .maxReconnectAttempts: return "Max Reconnect Attempts"
            case .autoReconnect: return "Auto Reconnect"
            case .debugLogging: return "Debug Logging"
            case .callKit: return "CallKit Integration"
            case .quickActions: return "Quick Actions"
            case .version: return "Version"
            case .documentation: return "Documentation"
            case .resetSettings: return "Reset All Settings"
            }
        }

        var isDestructive: Bool {
            return self == .resetSettings
        }
    }

    private var sectionRows: [SettingsSection: [SettingsRow]] {
        var rows: [SettingsSection: [SettingsRow]] = [
            .server: [.serverPreset, .testConnection],
            .audio: [.sampleRate, .audioOutput, .audioFormat],
            .connection: [.connectionTimeout, .maxReconnectAttempts, .autoReconnect],
            .features: [.debugLogging, .callKit, .quickActions],
            .about: [.version, .documentation, .resetSettings]
        ]

        // Show custom URL field only when custom preset is selected
        if settings.serverPreset == .custom {
            rows[.server]?.insert(.customURL, at: 1)
        }

        return rows
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupTableView()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemBackground

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange() {
        tableView.reloadData()
    }

    // MARK: - Actions

    private func showServerPresetPicker() {
        let alert = UIAlertController(
            title: "Select Server",
            message: "Choose a server preset or select Custom to enter your own URL",
            preferredStyle: .actionSheet
        )

        for preset in SettingsManager.ServerPreset.allCases {
            let action = UIAlertAction(title: preset.displayName, style: .default) { [weak self] _ in
                self?.settings.serverPreset = preset
                if preset == .custom {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.showCustomURLEditor()
                    }
                }
            }

            if preset == settings.serverPreset {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showCustomURLEditor() {
        let alert = UIAlertController(
            title: "Custom Server URL",
            message: "Enter the WebSocket URL for your backend server",
            preferredStyle: .alert
        )

        alert.addTextField { [weak self] textField in
            textField.placeholder = "ws://example.com:8080"
            textField.text = self?.settings.customServerURL
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let url = alert.textFields?.first?.text, !url.isEmpty else { return }
            self?.settings.customServerURL = url
            self?.showAlert(title: "Saved", message: "Custom server URL has been saved.")
        })

        present(alert, animated: true)
    }

    private func testConnection() {
        let serverURL = settings.serverURL

        let alert = UIAlertController(
            title: "Testing Connection",
            message: "Connecting to:\n\(serverURL)",
            preferredStyle: .alert
        )

        present(alert, animated: true)

        // Perform connection test
        guard let url = URL(string: serverURL) else {
            alert.dismiss(animated: true) {
                self.showAlert(title: "Invalid URL", message: "The server URL is not valid.")
            }
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()

        // Wait for connection with timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(settings.connectionTimeout)) {
            if task.state == .running {
                alert.dismiss(animated: true) {
                    self.showAlert(
                        title: "Connection Successful",
                        message: "Successfully connected to the server."
                    )
                }
            } else {
                alert.dismiss(animated: true) {
                    self.showAlert(
                        title: "Connection Failed",
                        message: "Could not connect to the server. Please check the URL and ensure the server is running."
                    )
                }
            }
            task.cancel()
        }

        // Also check for immediate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if task.state == .running {
                alert.dismiss(animated: true) {
                    self.showAlert(
                        title: "Connection Successful",
                        message: "Successfully connected to the server."
                    )
                }
                task.cancel()
            }
        }
    }

    private func showSampleRatePicker() {
        let alert = UIAlertController(
            title: "Sample Rate",
            message: "Higher sample rates provide better quality but use more bandwidth.",
            preferredStyle: .actionSheet
        )

        for rate in SettingsManager.SampleRate.allCases {
            let action = UIAlertAction(title: rate.displayName, style: .default) { [weak self] _ in
                self?.settings.sampleRate = rate.rawValue
            }

            if rate.rawValue == settings.sampleRate {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showAudioOutputPicker() {
        let alert = UIAlertController(
            title: "Audio Output",
            message: "Select where to play audio responses.",
            preferredStyle: .actionSheet
        )

        for mode in SettingsManager.AudioOutputMode.allCases {
            let action = UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.settings.audioOutputMode = mode
            }

            if mode == settings.audioOutputMode {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showTimeoutPicker() {
        let alert = UIAlertController(
            title: "Connection Timeout",
            message: "Select how long to wait for a connection before timing out.",
            preferredStyle: .actionSheet
        )

        let timeouts = [10, 15, 30, 45, 60]
        for timeout in timeouts {
            let action = UIAlertAction(title: "\(timeout) seconds", style: .default) { [weak self] _ in
                self?.settings.connectionTimeout = timeout
            }

            if timeout == settings.connectionTimeout {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showReconnectAttemptsPicker() {
        let alert = UIAlertController(
            title: "Max Reconnect Attempts",
            message: "Number of times to retry connecting after a disconnection.",
            preferredStyle: .actionSheet
        )

        let attempts = [1, 3, 5, 10, 0] // 0 means unlimited
        for attempt in attempts {
            let title = attempt == 0 ? "Unlimited" : "\(attempt)"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.settings.maxReconnectAttempts = attempt
            }

            if attempt == settings.maxReconnectAttempts {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showDocumentation() {
        let message = """
        Voice Agent Setup Guide:

        1. Server Configuration
           • Select a server preset or enter a custom URL
           • Use Tailscale for secure private networking
           • Test connection to verify connectivity

        2. Audio Settings
           • 16 kHz is recommended for speech
           • Higher sample rates use more bandwidth

        3. Connection Settings
           • Adjust timeout for slow networks
           • Enable auto-reconnect for reliability

        4. Quick Start
           • Grant microphone permissions when prompted
           • Use the Start button or Quick Action to begin
           • Speak clearly and wait for responses

        For more information, see the project README.
        """

        let alert = UIAlertController(title: "Documentation", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func confirmResetSettings() {
        let alert = UIAlertController(
            title: "Reset All Settings",
            message: "This will reset all settings to their default values. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.settings.resetToDefaults()
            self?.showAlert(title: "Settings Reset", message: "All settings have been restored to defaults.")
        })

        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func subtitleForRow(_ row: SettingsRow) -> String? {
        switch row {
        case .serverPreset:
            let preset = settings.serverPreset
            if preset == .custom {
                return settings.customServerURL.isEmpty ? "Not configured" : settings.customServerURL
            }
            return settings.serverURL
        case .customURL:
            return settings.customServerURL.isEmpty ? "Not set" : settings.customServerURL
        case .testConnection:
            return "Verify server connectivity"
        case .sampleRate:
            return SettingsManager.SampleRate(rawValue: settings.sampleRate)?.displayName ?? "\(settings.sampleRate) Hz"
        case .audioOutput:
            return settings.audioOutputMode.displayName
        case .audioFormat:
            return settings.audioFormatDescription
        case .connectionTimeout:
            return "\(settings.connectionTimeout) seconds"
        case .maxReconnectAttempts:
            return settings.maxReconnectAttempts == 0 ? "Unlimited" : "\(settings.maxReconnectAttempts)"
        case .autoReconnect, .debugLogging, .callKit, .quickActions:
            return nil // Handled by switch cell
        case .version:
            return settings.appVersion
        case .documentation:
            return "Setup guide and help"
        case .resetSettings:
            return nil
        }
    }

    private func handleRowSelection(_ row: SettingsRow) {
        switch row {
        case .serverPreset:
            showServerPresetPicker()
        case .customURL:
            showCustomURLEditor()
        case .testConnection:
            testConnection()
        case .sampleRate:
            showSampleRatePicker()
        case .audioOutput:
            showAudioOutputPicker()
        case .connectionTimeout:
            showTimeoutPicker()
        case .maxReconnectAttempts:
            showReconnectAttemptsPicker()
        case .documentation:
            showDocumentation()
        case .resetSettings:
            confirmResetSettings()
        case .audioFormat, .version, .autoReconnect, .debugLogging, .callKit, .quickActions:
            // No action or handled by switch
            break
        }
    }

    private func isSwitchRow(_ row: SettingsRow) -> Bool {
        return [.autoReconnect, .debugLogging, .callKit, .quickActions].contains(row)
    }

    private func switchValueForRow(_ row: SettingsRow) -> Bool {
        switch row {
        case .autoReconnect: return settings.autoReconnect
        case .debugLogging: return settings.debugLoggingEnabled
        case .callKit: return settings.callKitEnabled
        case .quickActions: return settings.quickActionsEnabled
        default: return false
        }
    }

    private func setSwitchValue(_ value: Bool, forRow row: SettingsRow) {
        switch row {
        case .autoReconnect: settings.autoReconnect = value
        case .debugLogging: settings.debugLoggingEnabled = value
        case .callKit: settings.callKitEnabled = value
        case .quickActions: settings.quickActionsEnabled = value
        default: break
        }
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }
        return sectionRows[settingsSection]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let settingsSection = SettingsSection(rawValue: indexPath.section),
              let rows = sectionRows[settingsSection],
              indexPath.row < rows.count else {
            return UITableViewCell()
        }

        let row = rows[indexPath.row]

        if isSwitchRow(row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.configure(title: row.title, isOn: switchValueForRow(row)) { [weak self] isOn in
                self?.setSwitchValue(isOn, forRow: row)
            }
            cell.selectionStyle = .none
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = row.title
        config.secondaryText = subtitleForRow(row)

        if row.isDestructive {
            config.textProperties.color = .systemRed
            cell.accessoryType = .none
        } else if row == .audioFormat || row == .version {
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
            config.textProperties.color = .label
        }

        config.secondaryTextProperties.color = .secondaryLabel

        cell.contentConfiguration = config
        cell.selectionStyle = (row == .audioFormat || row == .version) ? .none : .default

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.footer
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let settingsSection = SettingsSection(rawValue: indexPath.section),
              let rows = sectionRows[settingsSection],
              indexPath.row < rows.count else {
            return
        }

        let row = rows[indexPath.row]
        handleRowSelection(row)
    }
}

// MARK: - SwitchTableViewCell

class SwitchTableViewCell: UITableViewCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let switchControl: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()

    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }

    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func switchValueChanged() {
        onToggle?(switchControl.isOn)
    }
}
