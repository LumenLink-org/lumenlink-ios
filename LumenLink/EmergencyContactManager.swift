//
//  EmergencyContactManager.swift
//  LumenLink
//
//  Emergency Contact Manager - manages contacts and panic mode.
//

import Foundation
import CoreLocation
import MessageUI
import UIKit

protocol EmergencyContactManagerDelegate: AnyObject {
    func emergencyContactManager(_ manager: EmergencyContactManager, didActivatePanicMode: Bool)
    func emergencyContactManager(_ manager: EmergencyContactManager, didSendLocationUpdate: Bool)
}

final class EmergencyContactManager {
    static let shared = EmergencyContactManager()
    private let userDefaults = UserDefaults.standard
    private let locationManager = CLLocationManager()

    private let keyEnabled = "emergency_enabled"
    private let keyContactNumber = "emergency_contact_number"
    private let keyContactName = "emergency_contact_name"
    private let keyContacts = "emergency_contacts"
    private let keyPanicModeActive = "panic_mode_active"
    private let keyLastLocationSent = "last_location_sent"

    private let locationUpdateInterval: TimeInterval = 5 * 60
    private var locationUpdateTimer: Timer?

    weak var delegate: EmergencyContactManagerDelegate?

    private init() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var isEnabled: Bool { userDefaults.bool(forKey: keyEnabled) }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: keyEnabled)
        if !enabled { deactivatePanicMode() }
    }

    func getEmergencyContact() -> (number: String?, name: String?) {
        (userDefaults.string(forKey: keyContactNumber), userDefaults.string(forKey: keyContactName))
    }

    func setEmergencyContact(number: String, name: String?) {
        userDefaults.set(number, forKey: keyContactNumber)
        userDefaults.set(name, forKey: keyContactName)
    }

    func getAllContacts() -> [(number: String, name: String?)] {
        if let data = userDefaults.data(forKey: keyContacts),
           let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) {
            return decoded.compactMap { dict -> (String, String?)? in
                guard let num = dict["number"] else { return nil }
                return (num, dict["name"])
            }
        }
        if let num = userDefaults.string(forKey: keyContactNumber) {
            return [(num, userDefaults.string(forKey: keyContactName))]
        }
        return []
    }

    func setAllContacts(_ contacts: [(number: String, name: String?)]) {
        let encoded = contacts.map { ["number": $0.number, "name": $0.name ?? ""] }
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: keyContacts)
        }
    }

    func activatePanicMode() {
        guard isEnabled else { return }
        let contact = getEmergencyContact()
        guard let contactNumber = contact.number, !contactNumber.isEmpty else { return }
        userDefaults.set(true, forKey: keyPanicModeActive)
        startLocationUpdates()
        sendLocationUpdate(to: contactNumber, name: contact.name)
        for c in getAllContacts() { sendLocationUpdate(to: c.number, name: c.name) }
    }

    func deactivatePanicMode() {
        userDefaults.set(false, forKey: keyPanicModeActive)
        stopLocationUpdates()
    }

    var isPanicModeActive: Bool { userDefaults.bool(forKey: keyPanicModeActive) }

    private func startLocationUpdates() {
        stopLocationUpdates()
        requestLocationPermission()
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { [weak self] _ in
            for contact in self?.getAllContacts() ?? [] {
                self?.sendLocationUpdate(to: contact.number, name: contact.name)
            }
        }
        for contact in getAllContacts() { sendLocationUpdate(to: contact.number, name: contact.name) }
    }

    private func stopLocationUpdates() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }

    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: locationManager.startUpdatingLocation()
        default: break
        }
    }

    private func sendLocationUpdate(to contactNumber: String, name: String?) {
        guard let location = locationManager.location else { return }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let url = "https://maps.apple.com/?ll=\(location.coordinate.latitude),\(location.coordinate.longitude)"
        let message = """
        🚨 LUMENLINK EMERGENCY ALERT 🚨
        Time: \(timestamp)
        Location: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Map: \(url)
        """
        if MFMessageComposeViewController.canSendText(),
           let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController {
            let controller = MFMessageComposeViewController()
            controller.recipients = [contactNumber]
            controller.body = message
            controller.messageComposeDelegate = self
            rootVC.present(controller, animated: true)
        } else {
            let smsURL = "sms:\(contactNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: smsURL) { UIApplication.shared.open(url) }
        }
        let whatsappURL = "https://wa.me/\(contactNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: whatsappURL), UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
        userDefaults.set(Date().timeIntervalSince1970, forKey: keyLastLocationSent)
    }
}

extension EmergencyContactManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

extension EmergencyContactManager: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}
