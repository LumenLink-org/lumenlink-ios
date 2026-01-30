//
//  ConnectionStatusManager.swift
//  LumenLink
//
//  Global connection status for VPN.
//

import Foundation
import Combine

/// Connection status manager - singleton for VPN state
final class ConnectionStatusManager {
    static let shared = ConnectionStatusManager()

    enum Status {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    @Published private(set) var status: Status = .disconnected

    private init() {}

    func setConnecting() {
        status = .connecting
    }

    func setConnected() {
        status = .connected
    }

    func setDisconnected() {
        status = .disconnected
    }

    func setError(_ message: String) {
        status = .error(message)
    }
}
