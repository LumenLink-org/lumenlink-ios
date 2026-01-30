//
//  SettingsViewController.swift
//  LumenLink
//
//  Main settings screen - Discovery, PERSIA Mode, Emergency Contacts.
//

import UIKit

final class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

enum SettingsRow: Int, CaseIterable {
    case discoveryChannels = 0
    case persiaMode
    case emergencyContacts

    var title: String {
        switch self {
        case .discoveryChannels: return "Discovery Channels"
        case .persiaMode: return "PERSIA Mode"
        case .emergencyContacts: return "Emergency Contacts"
        }
    }

    var subtitle: String? {
        switch self {
        case .discoveryChannels: return "GPS, UWB, and other discovery"
        case .persiaMode: return "Share connectivity as gateway"
        case .emergencyContacts: return "Panic mode and contacts"
        }
    }
}

extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SettingsRow.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SettingsCell")
        let row = SettingsRow(rawValue: indexPath.row) ?? .discoveryChannels
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = SettingsRow(rawValue: indexPath.row) ?? .discoveryChannels
        switch row {
        case .discoveryChannels:
            navigationController?.pushViewController(DiscoverySettingsViewController(), animated: true)
        case .persiaMode:
            navigationController?.pushViewController(PersiaModeViewController(), animated: true)
        case .emergencyContacts:
            navigationController?.pushViewController(EmergencyContactViewController(), animated: true)
        }
    }
}
