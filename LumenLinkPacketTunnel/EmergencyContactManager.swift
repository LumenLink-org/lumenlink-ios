//
//  EmergencyContactManager.swift
//  LumenLink
//
//  Emergency Contact Manager for iOS
//  Manages emergency contacts and panic mode functionality
//

import Foundation
import CoreLocation
import MessageUI
import Contacts
import UIKit

/**
 * Emergency Contact Manager
 * 
 * Manages emergency contacts and panic mode functionality:
 * - Stores user-defined emergency contact numbers
 * - Detects panic mode (automatic or manual)
 * - Sends location updates via SMS/WhatsApp every 5 minutes during panic mode
 * - Supports voice activation (Siri)
 */
class EmergencyContactManager {
    
    private let userDefaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    
    private let keyEnabled = "emergency_enabled"
    private let keyContactNumber = "emergency_contact_number"
    private let keyContactName = "emergency_contact_name"
    private let keyPanicModeActive = "panic_mode_active"
    private let keyLastLocationSent = "last_location_sent"
    
    private let panicDetectionInterval: TimeInterval = 5 * 60 // 5 minutes
    private let locationUpdateInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private var locationUpdateTimer: Timer?
    private var panicDetectionTimer: Timer?
    
    weak var delegate: EmergencyContactManagerDelegate?
    
    init() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /**
     * Check if emergency contact feature is enabled
     */
    var isEnabled: Bool {
        return userDefaults.bool(forKey: keyEnabled)
    }
    
    /**
     * Enable or disable emergency contact feature
     */
    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: keyEnabled)
        
        if enabled {
            startPanicModeMonitoring()
        } else {
            stopPanicModeMonitoring()
            deactivatePanicMode()
        }
        
        print("Emergency contact feature \(enabled ? "enabled" : "disabled")")
    }
    
    /**
     * Get emergency contact number and name
     */
    func getEmergencyContact() -> (number: String?, name: String?) {
        let number = userDefaults.string(forKey: keyContactNumber)
        let name = userDefaults.string(forKey: keyContactName)
        return (number, name)
    }
    
    /**
     * Set emergency contact number and name
     */
    func setEmergencyContact(number: String, name: String?) {
        userDefaults.set(number, forKey: keyContactNumber)
        userDefaults.set(name, forKey: keyContactName)
        
        print("Emergency contact set: \(name ?? "Unknown") (\(number))")
    }
    
    /**
     * Activate panic mode manually
     */
    func activatePanicMode() {
        guard isEnabled else {
            print("Cannot activate panic mode: feature is disabled")
            return
        }
        
        let contact = getEmergencyContact()
        guard let contactNumber = contact.number, !contactNumber.isEmpty else {
            print("Cannot activate panic mode: no emergency contact set")
            return
        }
        
        userDefaults.set(true, forKey: keyPanicModeActive)
        startLocationUpdates()
        
        // Send immediate location update
        sendLocationUpdate(to: contactNumber, name: contact.name)
        
        print("Panic mode activated")
    }
    
    /**
     * Deactivate panic mode
     */
    func deactivatePanicMode() {
        userDefaults.set(false, forKey: keyPanicModeActive)
        stopLocationUpdates()
        
        print("Panic mode deactivated")
    }
    
    /**
     * Check if panic mode is currently active
     */
    var isPanicModeActive: Bool {
        return userDefaults.bool(forKey: keyPanicModeActive)
    }
    
    /**
     * Start monitoring for automatic panic mode detection
     */
    private func startPanicModeMonitoring() {
        stopPanicModeMonitoring()
        
        panicDetectionTimer = Timer.scheduledTimer(withTimeInterval: panicDetectionInterval, repeats: true) { [weak self] _ in
            // TODO: Implement automatic panic detection
            // Examples:
            // - Sudden network disconnection
            // - VPN connection failure
            // - Multiple failed authentication attempts
            // - Device tampering detection
            // - Accelerometer patterns (fall detection)
            
            // For now, panic mode must be activated manually
            // or via voice command (Siri)
        }
    }
    
    /**
     * Stop panic mode monitoring
     */
    private func stopPanicModeMonitoring() {
        panicDetectionTimer?.invalidate()
        panicDetectionTimer = nil
    }
    
    /**
     * Start sending location updates every 5 minutes
     */
    private func startLocationUpdates() {
        stopLocationUpdates()
        
        // Request location permission if needed
        requestLocationPermission()
        
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let contact = self.getEmergencyContact()
            if let contactNumber = contact.number, !contactNumber.isEmpty {
                self.sendLocationUpdate(to: contactNumber, name: contact.name)
            }
        }
        
        // Send immediate update
        let contact = getEmergencyContact()
        if let contactNumber = contact.number {
            sendLocationUpdate(to: contactNumber, name: contact.name)
        }
    }
    
    /**
     * Stop location updates
     */
    private func stopLocationUpdates() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    /**
     * Request location permission
     */
    private func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location permission denied")
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    /**
     * Send location update via SMS and WhatsApp
     */
    private func sendLocationUpdate(to contactNumber: String, name: String?) {
        guard let location = locationManager.location else {
            print("Could not get current location")
            return
        }
        
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .medium
        )
        
        let locationUrl = "https://maps.apple.com/?ll=\(location.coordinate.latitude),\(location.coordinate.longitude)"
        let message = """
        🚨 LUMENLINK EMERGENCY ALERT 🚨

        Time: \(timestamp)
        Location: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Accuracy: \(location.horizontalAccuracy)m
        Map: \(locationUrl)

        This is an automated emergency alert from LumenLink.
        """
        
        // Send via SMS
        sendSMS(to: contactNumber, message: message)
        
        // Send via WhatsApp (if available)
        sendWhatsApp(to: contactNumber, message: message)
        
        // Update last sent timestamp
        userDefaults.set(Date().timeIntervalSince1970, forKey: keyLastLocationSent)
    }
    
    /**
     * Send SMS message
     */
    private func sendSMS(to phoneNumber: String, message: String) {
        if MFMessageComposeViewController.canSendText() {
            let controller = MFMessageComposeViewController()
            controller.recipients = [phoneNumber]
            controller.body = message
            controller.messageComposeDelegate = self
            
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                rootViewController.present(controller, animated: true)
            }
        } else {
            // Fallback: Open Messages app with pre-filled content
            let smsURL = "sms:\(phoneNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: smsURL) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /**
     * Send WhatsApp message
     */
    private func sendWhatsApp(to phoneNumber: String, message: String) {
        // Format phone number (remove + and spaces)
        let formattedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        let whatsappURL = "https://wa.me/\(formattedNumber)?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: whatsappURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /**
     * Handle Siri shortcut to activate panic mode
     */
    func handleSiriShortcut() {
        print("Siri shortcut triggered")
        activatePanicMode()
    }
    
    /**
     * Handle voice command
     */
    func handleVoiceCommand(_ command: String) {
        let lowerCommand = command.lowercased()
        
        if lowerCommand.contains("panic") || 
           lowerCommand.contains("emergency") ||
           lowerCommand.contains("help") {
            activatePanicMode()
        } else if lowerCommand.contains("stop") && lowerCommand.contains("panic") {
            deactivatePanicMode()
        }
    }
    
    /**
     * Cleanup resources
     */
    func cleanup() {
        stopPanicModeMonitoring()
        stopLocationUpdates()
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension EmergencyContactManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updated
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || 
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - MFMessageComposeViewControllerDelegate
extension EmergencyContactManager: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

// MARK: - Protocol
protocol EmergencyContactManagerDelegate: AnyObject {
    func emergencyContactManager(_ manager: EmergencyContactManager, didActivatePanicMode: Bool)
    func emergencyContactManager(_ manager: EmergencyContactManager, didSendLocationUpdate: Bool)
}
