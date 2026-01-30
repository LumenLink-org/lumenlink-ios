//
//  GpsDiscoveryService.swift
//  LumenLink
//
//  GPS-based discovery channel.
//

import Foundation
import CoreLocation

final class GpsDiscoveryService: NSObject {
    private let locationManager = CLLocationManager()
    private var onResult: ((ChannelResult) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startDiscovery(onResult: @escaping (ChannelResult) -> Void) {
        self.onResult = onResult

        guard CLLocationManager.locationServicesEnabled() else {
            onResult(ChannelResult(channel: .gps, success: false, errorMessage: "Location services disabled"))
            return
        }

        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            onResult(ChannelResult(channel: .gps, success: false, errorMessage: "Location permission denied"))
            return
        }

        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        locationManager.requestLocation()
    }

    func stopDiscovery() {
        onResult = nil
    }
}

extension GpsDiscoveryService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onResult?(ChannelResult(channel: .gps, success: true, gatewaysFound: 0, latencyMs: nil))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onResult?(ChannelResult(channel: .gps, success: false, errorMessage: error.localizedDescription))
    }
}
