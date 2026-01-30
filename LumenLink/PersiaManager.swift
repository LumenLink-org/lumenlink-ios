//
//  PersiaManager.swift
//  LumenLink
//
//  PERSIA Mode: credential exchange and gateway mode.
//

import Foundation
import CryptoKit

final class PersiaManager {
    static let shared = PersiaManager()
    @Published private(set) var isEnabled = false
    @Published private(set) var bandwidthLimitMbps = 100
    @Published private(set) var connectedPeers = 0
    @Published private(set) var connectedToGateway = false
    private let prefs = UserDefaults.standard
    private init() {}

    func generateCredentials() -> PersiaCredentials {
        let key = SymmetricKey(size: .bits256)
        let iv = AES.GCM.Nonce()
        let data = "lumenlink-persia-\(Date().timeIntervalSince1970)".data(using: .utf8)!
        let sealed = try? AES.GCM.seal(data, using: key, nonce: iv)
        let encrypted = sealed?.combined?.base64EncodedString() ?? ""
        let ivB64 = Data(iv).base64EncodedString()
        return PersiaCredentials(token: encrypted, iv: ivB64, expiresAt: Date().timeIntervalSince1970 + 3600)
    }

    func exchangeCredentials(peerToken: String) -> Bool {
        let parts = peerToken.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let cred = PersiaCredentials(token: String(parts[0]), iv: String(parts[1]), expiresAt: Date().timeIntervalSince1970 + 3600)
        if cred.expiresAt < Date().timeIntervalSince1970 { return false }
        connectedToGateway = true
        prefs.set(true, forKey: "connected_to_gateway")
        return true
    }

    func getShareableCredential() -> String {
        let cred = generateCredentials()
        return "\(cred.token).\(cred.iv)"
    }

    func enable(bandwidthLimitMbps: Int = 100) {
        isEnabled = true
        self.bandwidthLimitMbps = bandwidthLimitMbps
    }

    func disable() {
        isEnabled = false
        connectedPeers = 0
    }

    func updateConnectedPeers(_ count: Int) {
        connectedPeers = count
    }
}

struct PersiaCredentials {
    let token: String
    let iv: String
    let expiresAt: TimeInterval
}
