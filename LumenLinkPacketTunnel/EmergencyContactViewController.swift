//
//  EmergencyContactViewController.swift
//  LumenLink
//
//  UI for managing emergency contact settings
//

import UIKit

/**
 * Emergency Contact Settings View Controller
 * 
 * UI for managing emergency contact settings:
 * - Enable/disable feature
 * - Set emergency contact number and name
 * - Activate/deactivate panic mode
 * - View panic mode status
 */
class EmergencyContactViewController: UIViewController {
    
    private let emergencyManager = EmergencyContactManager()
    private let siriIntegration: SiriIntegration
    
    private var enableSwitch: UISwitch!
    private var contactNumberField: UITextField!
    private var contactNameField: UITextField!
    private var saveButton: UIButton!
    private var panicModeButton: UIButton!
    private var statusLabel: UILabel!
    
    init() {
        siriIntegration = SiriIntegration(emergencyManager: emergencyManager)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Emergency Contact"
        view.backgroundColor = .systemBackground
        
        setupUI()
        loadSettings()
        
        // Request permissions
        requestPermissions()
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
        
        // Enable/Disable Switch
        let enableLabel = UILabel()
        enableLabel.text = "Enable Emergency Contact"
        enableSwitch = UISwitch()
        enableSwitch.addTarget(self, action: #selector(enableSwitchChanged), for: .valueChanged)
        
        let enableStack = UIStackView(arrangedSubviews: [enableLabel, enableSwitch])
        enableStack.axis = .horizontal
        enableStack.distribution = .equalSpacing
        stackView.addArrangedSubview(enableStack)
        
        // Contact Number Input
        let numberLabel = UILabel()
        numberLabel.text = "Emergency Contact Number"
        contactNumberField = UITextField()
        contactNumberField.placeholder = "+1234567890"
        contactNumberField.keyboardType = .phonePad
        contactNumberField.borderStyle = .roundedRect
        stackView.addArrangedSubview(numberLabel)
        stackView.addArrangedSubview(contactNumberField)
        
        // Contact Name Input
        let nameLabel = UILabel()
        nameLabel.text = "Contact Name (Optional)"
        contactNameField = UITextField()
        contactNameField.placeholder = "John Doe"
        contactNameField.borderStyle = .roundedRect
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(contactNameField)
        
        // Save Button
        saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Contact", for: .normal)
        saveButton.addTarget(self, action: #selector(saveContact), for: .touchUpInside)
        stackView.addArrangedSubview(saveButton)
        
        // Panic Mode Button
        panicModeButton = UIButton(type: .system)
        panicModeButton.setTitle("Activate Panic Mode", for: .normal)
        panicModeButton.addTarget(self, action: #selector(togglePanicMode), for: .touchUpInside)
        stackView.addArrangedSubview(panicModeButton)
        
        // Status Label
        statusLabel = UILabel()
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 14)
        stackView.addArrangedSubview(statusLabel)
        
        // Voice Commands Info
        let voiceInfoLabel = UILabel()
        voiceInfoLabel.text = """
        Voice Commands:
        • "Hey Siri, activate panic mode"
        • "Hey Siri, emergency"
        • "Hey Siri, help"
        • "Hey Siri, stop panic mode"
        """
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
        guard let number = contactNumberField.text?.trimmingCharacters(in: .whitespaces),
              !number.isEmpty else {
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
        
        // Enable/disable UI elements
        contactNumberField.isEnabled = isEnabled
        contactNameField.isEnabled = isEnabled
        saveButton.isEnabled = isEnabled
        panicModeButton.isEnabled = isEnabled && !(contact.number?.isEmpty ?? true)
        
        // Update panic mode button
        panicModeButton.setTitle(
            isPanicActive ? "Deactivate Panic Mode" : "Activate Panic Mode",
            for: .normal
        )
        
        // Update status
        var status = "Status: "
        if !isEnabled {
            status += "Disabled"
        } else if contact.number?.isEmpty ?? true {
            status += "No contact set"
        } else if isPanicActive {
            status += "PANIC MODE ACTIVE - Location updates every 5 minutes"
        } else {
            status += "Ready - Contact: \(contact.name ?? contact.number ?? "Unknown")"
        }
        statusLabel.text = status
        
        // Donate Siri shortcut if enabled
        if isEnabled {
            siriIntegration.donateShortcut()
        }
    }
    
    private func requestPermissions() {
        // Location permission is requested by EmergencyContactManager
        // Speech recognition permission is handled by iOS automatically
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
