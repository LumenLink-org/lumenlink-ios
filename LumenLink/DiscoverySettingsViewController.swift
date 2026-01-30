//
//  DiscoverySettingsViewController.swift
//  LumenLink
//
//  Discovery channel selection UI with telemetry.
//

import UIKit
import Combine

final class DiscoverySettingsViewController: UIViewController {
    private let discoveryManager = DiscoveryManager()

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let scanButton = UIButton(type: .system)
    private let persiaModeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Discovery Channels"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        scanButton.setTitle("Scan Channels", for: .normal)
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        scanButton.translatesAutoresizingMaskIntoConstraints = false

        persiaModeButton.setTitle("PERSIA Mode", for: .normal)
        persiaModeButton.addTarget(self, action: #selector(persiaModeTapped), for: .touchUpInside)
        persiaModeButton.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(scanButton)
        view.addSubview(persiaModeButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 16),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            persiaModeButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 8),
            persiaModeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            persiaModeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            persiaModeButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func scanTapped() {
        discoveryManager.scanChannels { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    @objc private func persiaModeTapped() {
        navigationController?.pushViewController(PersiaModeViewController(), animated: true)
    }
}

extension DiscoverySettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DiscoveryChannel.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChannelCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ChannelCell")
        let channel = DiscoveryChannel.allCases[indexPath.row]
        cell.textLabel?.text = channel.displayName
        cell.accessoryType = discoveryManager.isChannelEnabled(channel) ? .checkmark : .none
        let successRate = discoveryManager.getSuccessRate(for: channel)
        let lastResult = discoveryManager.getLastResult(for: channel)
        if successRate > 0 || lastResult != nil {
            var detail = ""
            if successRate > 0 { detail += "Success: \(Int(successRate * 100))%" }
            if let r = lastResult {
                if !detail.isEmpty { detail += " • " }
                detail += r.success ? "Last: OK" : "Last: \(r.errorMessage ?? "Failed")"
                if let lat = r.latencyMs { detail += " (\(lat)ms)" }
            }
            cell.detailTextLabel?.text = detail
        } else {
            cell.detailTextLabel?.text = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let channel = DiscoveryChannel.allCases[indexPath.row]
        discoveryManager.setChannelEnabled(channel, enabled: !discoveryManager.isChannelEnabled(channel))
        tableView.reloadData()
    }
}
