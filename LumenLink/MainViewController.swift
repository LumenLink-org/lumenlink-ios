//
//  MainViewController.swift
//  LumenLink
//
//  Connection status UI - Connect/Disconnect, status display.
//

import UIKit
import NetworkExtension
import Combine

final class MainViewController: UIViewController {
    private let statusLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "LumenLink"
        view.backgroundColor = .systemBackground
        setupUI()
        observeStatus()
    }

    private func setupUI() {
        statusLabel.text = "Disconnected"
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .title2)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        connectButton.setTitle("Connect", for: .normal)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false

        disconnectButton.setTitle("Disconnect", for: .normal)
        disconnectButton.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        disconnectButton.isHidden = true
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.setTitle("Settings", for: .normal)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)
        view.addSubview(connectButton)
        view.addSubview(disconnectButton)
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            disconnectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            disconnectButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 16)
        ])
    }

    private func observeStatus() {
        ConnectionStatusManager.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateStatus(status)
            }
            .store(in: &cancellables)
    }

    private func updateStatus(_ status: ConnectionStatusManager.Status) {
        switch status {
        case .disconnected:
            statusLabel.text = "Disconnected"
            connectButton.isHidden = false
            disconnectButton.isHidden = true
        case .connecting:
            statusLabel.text = "Connecting…"
            connectButton.isHidden = true
            disconnectButton.isHidden = true
        case .connected:
            statusLabel.text = "Connected"
            connectButton.isHidden = true
            disconnectButton.isHidden = false
        case .error(let msg):
            statusLabel.text = msg
            connectButton.isHidden = false
            disconnectButton.isHidden = true
        }
    }

    @objc private func connectTapped() {
        loadAndConnectVPN()
    }

    @objc private func disconnectTapped() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            managers?.first?.connection.stopVPNTunnel()
            ConnectionStatusManager.shared.setDisconnected()
        }
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    private func loadAndConnectVPN() {
        ConnectionStatusManager.shared.setConnecting()
        Task {
            do {
                // Fetch config from API before connecting
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-unknown"
                let configData = try await ApiClient.shared.getConfigData(deviceId: deviceId, region: "us-east-1")
                await MainActor.run {
                    self.connectVPNWithConfig(configData)
                }
            } catch {
                await MainActor.run {
                    ConnectionStatusManager.shared.setError("Config fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func connectVPNWithConfig(_ configData: Data) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            guard let self = self else { return }
            let manager = managers?.first ?? NETunnelProviderManager()
            manager.localizedDescription = "LumenLink"
            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = "com.lumenlink.LumenLinkPacketTunnel"
            config.serverAddress = "LumenLink"
            // Store config for tunnel to read
            config.providerConfiguration = ["config_pack": configData]
            manager.protocolConfiguration = config
            manager.isEnabled = true
            manager.saveToPreferences { err in
                if err != nil {
                    manager.loadFromPreferences { _ in
                        self.connectVPN(manager)
                    }
                } else {
                    self.connectVPN(manager)
                }
            }
        }
    }

    private func connectVPN(_ manager: NETunnelProviderManager) {
        ConnectionStatusManager.shared.setConnecting()
        // Pass config via options (tunnel reads from protocolConfiguration.providerConfiguration)
        let options: [String: NSObject] = [:]
        do {
            try manager.connection.startVPNTunnel(options: options)
            ConnectionStatusManager.shared.setConnected()
        } catch {
            ConnectionStatusManager.shared.setError(error.localizedDescription)
        }
    }
}
