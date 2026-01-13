import UIKit

class SettingsViewController: UIViewController {

    // MARK: - UI Components

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    // MARK: - Properties

    private enum SettingsSection: Int, CaseIterable {
        case connection
        case audio
        case about

        var title: String {
            switch self {
            case .connection: return "Connection"
            case .audio: return "Audio"
            case .about: return "About"
            }
        }
    }

    private struct SettingsItem {
        let title: String
        let subtitle: String?
        let action: () -> Void
    }

    private var sections: [SettingsSection: [SettingsItem]] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupTableView()
        loadSettings()
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
    }

    private func loadSettings() {
        let currentServerURL = UserDefaults.standard.string(forKey: "serverURL") ?? VoiceAgentManager.Configuration.defaultServerURL

        sections[.connection] = [
            SettingsItem(
                title: "Server URL",
                subtitle: currentServerURL,
                action: { [weak self] in self?.showServerURLEditor() }
            ),
            SettingsItem(
                title: "Test Connection",
                subtitle: "Verify connection to DGX Spark",
                action: { [weak self] in self?.testConnection() }
            )
        ]

        sections[.audio] = [
            SettingsItem(
                title: "Sample Rate",
                subtitle: "16 kHz (optimized for speech)",
                action: {}
            ),
            SettingsItem(
                title: "Audio Format",
                subtitle: "PCM 16-bit mono",
                action: {}
            )
        ]

        sections[.about] = [
            SettingsItem(
                title: "Version",
                subtitle: "1.0.0",
                action: {}
            ),
            SettingsItem(
                title: "Documentation",
                subtitle: "View setup guide",
                action: { [weak self] in self?.showDocumentation() }
            )
        ]
    }

    // MARK: - Actions

    private func showServerURLEditor() {
        let alert = UIAlertController(
            title: "Server URL",
            message: "Enter the WebSocket URL for your DGX Spark backend",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "ws://dgx-spark.tail-scale.ts.net:8080"
            textField.text = UserDefaults.standard.string(forKey: "serverURL")
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                VoiceAgentManager.shared.updateServerURL(url)
                self?.loadSettings()
                self?.tableView.reloadData()

                self?.showAlert(title: "Success", message: "Server URL updated successfully")
            }
        })

        present(alert, animated: true)
    }

    private func testConnection() {
        // Simple connection test
        showAlert(title: "Connection Test", message: "Testing connection to DGX Spark...\n\nThis feature is under development.")
    }

    private func showDocumentation() {
        let message = """
        Voice Agent Setup Guide:

        1. Ensure DGX Spark is running with NVIDIA Blueprint
        2. Configure Tailscale on both devices
        3. Set the correct server URL in settings
        4. Enable microphone permissions
        5. Use Quick Action or start button to begin

        For more information, see the README.md file.
        """

        let alert = UIAlertController(title: "Documentation", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }
        return sections[settingsSection]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        guard let settingsSection = SettingsSection(rawValue: indexPath.section),
              let item = sections[settingsSection]?[indexPath.row] else {
            return cell
        }

        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.title
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let settingsSection = SettingsSection(rawValue: indexPath.section),
              let item = sections[settingsSection]?[indexPath.row] else {
            return
        }

        item.action()
    }
}
