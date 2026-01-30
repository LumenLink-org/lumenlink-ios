//
//  EmergencyContactViewController.swift
//  LumenLink
//
//  UI for managing emergency contact settings.
//

import UIKit

final class EmergencyContactViewController: UIViewController {
    private let emergencyManager = EmergencyContactManager.shared
    private let siriIntegration = SiriIntegration()

    private var enableSwitch: UISwitch!
    private var contactNumberField: UITextField!
    private var contactNameField: UITextField!
    private var saveButton: UIButton!
    private var panicModeButton: UIButton!
    private var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Emergency Contact"
        view.backgroundColor = .systemBackground
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let enableLabel = UILabel()
        enableLabel.text = "Enable Emergency Contact"
        enableSwitch = UISwitch()
        enableSwitch.addTarget(self, action: #selector(enableSwitchChanged), for: .valueChanged)
        let enableStack = UIStackView(arrangedSubviews: [enableLabel, enableSwitch])
        enableStack.axis = .horizontal
        enableStack.distribution = .equalSpacing
        stackView.addArrangedSubview(enableStack)

        let numberLabel = UILabel()
        numberLabel.text = "Emergency Contact Number"
        contactNumberField = UITextField()
        contactNumberField.placeholder = "+1234567890"
        contactNumberField.keyboardType = .phonePad
        contactNumberField.borderStyle = .roundedRect
        stackView.addArrangedSubview(numberLabel)
        stackView.addArrangedSubview(contactNumberField)

        let nameLabel = UILabel()
        nameLabel.text = "Contact Name (Optional)"
        contactNameField = UITextField()
        contactNameField.placeholder = "John Doe"
        contactNameField.borderStyle = .roundedRect
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(contactNameField)

        saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Contact", for: .normal)
        saveButton.addTarget(self, action: #selector(saveContact), for: .touchUpInside)
        stackView.addArrangedSubview(saveButton)

        panicModeButton = UIButton(type: .system)
        panicModeButton.setTitle("Activate Panic Mode", for: .normal)
        panicModeButton.addTarget(self, action: #selector(togglePanicMode), for: .touchUpInside)
        stackView.addArrangedSubview(panicModeButton)

        statusLabel = UILabel()
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 14)
        stackView.addArrangedSubview(statusLabel)

        let voiceInfoLabel = UILabel()
        voiceInfoLabel.text = "Voice: \"Hey Siri, activate panic mode\" or \"Hey Siri, emergency\""
        voiceInfoLabel.numberOfLines = 0
        voiceInfoLabel.font = .systemFont(ofSize: 12)
        voiceInfoLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(voiceInfoLabel)
    }

    private func loadSettings() {
        enableSwitch.isOn = emergencyManager.isEnabled
        let contact = emergencyManager.getEmergencyContact()
        contactNumberField.text = contact.number
        contactNameField.text = contact.name
        updateUI()
    }

    @objc private func enableSwitchChanged() {
        emergencyManager.setEnabled(enableSwitch.isOn)
        updateUI()
    }

    @objc private func saveContact() {
        guard let number = contactNumberField.text?.trimmingCharacters(in: .whitespaces), !number.isEmpty else {
            showAlert(title: "Error", message: "Please enter a contact number")
            return
        }
        let name = contactNameField.text?.trimmingCharacters(in: .whitespaces)
        emergencyManager.setEmergencyContact(number: number, name: name?.isEmpty == true ? nil : name)
        showAlert(title: "Success", message: "Emergency contact saved")
        updateUI()
    }

    @objc private func togglePanicMode() {
        if emergencyManager.isPanicModeActive {
            emergencyManager.deactivatePanicMode()
            showAlert(title: "Panic Mode", message: "Panic mode deactivated")
        } else {
            emergencyManager.activatePanicMode()
            showAlert(title: "Panic Mode", message: "Panic mode activated")
        }
        updateUI()
    }

    private func updateUI() {
        let isEnabled = emergencyManager.isEnabled
        let isPanicActive = emergencyManager.isPanicModeActive
        let contact = emergencyManager.getEmergencyContact()

        contactNumberField.isEnabled = isEnabled
        contactNameField.isEnabled = isEnabled
        saveButton.isEnabled = isEnabled
        panicModeButton.isEnabled = isEnabled && !(contact.number?.isEmpty ?? true)
        panicModeButton.setTitle(isPanicActive ? "Deactivate Panic Mode" : "Activate Panic Mode", for: .normal)

        var status = "Status: "
        if !isEnabled { status += "Disabled" }
        else if contact.number?.isEmpty ?? true { status += "No contact set" }
        else if isPanicActive { status += "PANIC MODE ACTIVE" }
        else { status += "Ready - \(contact.name ?? contact.number ?? "Unknown")" }
        statusLabel.text = status

        if isEnabled { siriIntegration.donateShortcut() }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
