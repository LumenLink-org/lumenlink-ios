//
//  PersiaModeViewController.swift
//  LumenLink
//
//  PERSIA Mode UI - share credentials, connect with peer.
//

import UIKit
import Combine

final class PersiaModeViewController: UIViewController {
    private let persiaManager = PersiaManager.shared
    private let dataForwarder = PersiaDataForwarder()
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let enableSwitch = UISwitch()
    private let bandwidthField = UITextField()
    private let connectedPeersLabel = UILabel()
    private let shareButton = UIButton(type: .system)
    private let peerTokenField = UITextField()
    private let connectButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "PERSIA Mode"
        view.backgroundColor = .systemBackground
        setupUI()
        observeState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dataForwarder.stop()
    }

    private func setupUI() {
        titleLabel.text = "PERSIA Mode"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        descLabel.text = "Share your connectivity with others during emergencies. Enable to become a gateway."
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        enableSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false

        bandwidthField.placeholder = "100"
        bandwidthField.text = "100"
        bandwidthField.keyboardType = .numberPad
        bandwidthField.borderStyle = .roundedRect
        bandwidthField.translatesAutoresizingMaskIntoConstraints = false

        connectedPeersLabel.text = "Connected peers: 0"
        connectedPeersLabel.translatesAutoresizingMaskIntoConstraints = false

        shareButton.setTitle("Copy credentials", for: .normal)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        peerTokenField.placeholder = "Enter peer token"
        peerTokenField.borderStyle = .roundedRect
        peerTokenField.translatesAutoresizingMaskIntoConstraints = false

        connectButton.setTitle("Connect", for: .normal)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, descLabel,
            makeRow(label: "Enable PERSIA Mode", view: enableSwitch),
            makeRow(label: "Bandwidth limit (Mbps)", view: bandwidthField),
            connectedPeersLabel,
            shareButton,
            peerTokenField,
            connectButton
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bandwidthField.heightAnchor.constraint(equalToConstant: 44),
            peerTokenField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makeRow(label: String, view: UIView) -> UIStackView {
        let lbl = UILabel()
        lbl.text = label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView(arrangedSubviews: [lbl, view])
        row.axis = .horizontal
        row.distribution = .fill
        return row
    }

    private func observeState() {
        persiaManager.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.enableSwitch.isOn = enabled
                self?.shareButton.isEnabled = enabled
                self?.connectButton.isEnabled = enabled
                if enabled { self?.dataForwarder.start() } else { self?.dataForwarder.stop() }
            }
            .store(in: &cancellables)

        persiaManager.$connectedPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.connectedPeersLabel.text = "Connected peers: \(count)"
            }
            .store(in: &cancellables)
    }

    @objc private func switchChanged() {
        if enableSwitch.isOn {
            let limit = Int(bandwidthField.text ?? "100") ?? 100
            persiaManager.enable(bandwidthLimitMbps: limit)
        } else {
            persiaManager.disable()
        }
    }

    @objc private func shareTapped() {
        let cred = persiaManager.getShareableCredential()
        UIPasteboard.general.string = cred
        let alert = UIAlertController(title: "Copied", message: "Credentials copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func connectTapped() {
        let token = peerTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            let alert = UIAlertController(title: "Error", message: "Enter peer token", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        if persiaManager.exchangeCredentials(peerToken: token) {
            peerTokenField.text = ""
            let alert = UIAlertController(title: "Connected", message: "Peer connected", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Failed", message: "Failed to connect with peer", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
