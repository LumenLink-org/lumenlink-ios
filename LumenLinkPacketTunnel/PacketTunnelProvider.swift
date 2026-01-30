//
//  PacketTunnelProvider.swift
//  LumenLinkPacketTunnel
//
//  iOS NetworkExtension for LumenLink VPN
//

import NetworkExtension
import Foundation

/// LumenLink Packet Tunnel Provider
/// 
/// Routes all device traffic through LumenLink tunnel using TUN interface.
class LumenLinkPacketTunnel: NEPacketTunnelProvider {
    
    private var rustCore: RustCore?
    private var tunnelHandle: UnsafeMutableRawPointer?
    private var tunnelManager: TunnelManager?
    private var uwbDiscoveryManager: Any? // UWBDiscoveryManager when iOS 14+
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Task {
            do {
                // Load signed config pack (from options passed by main app, or fetch from API)
                let config = try await loadSignedConfigPack(options: options)
                
                // Perform remote attestation (DCAppAttest) - fallback allows connection if attestation fails
                if #available(iOS 14.0, *) {
                    _ = try await performAttestation()
                }
                
                // Initialize Rust core and start tunnel
                rustCore = try RustCore(config: config)
                let configJson = configToJson(config)
                if let handle = rustCore?.startTunnel(configJson: configJson) {
                    tunnelHandle = handle
                }
                
                // Configure tunnel network settings
                let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
                
                // IPv4 settings
                let ipv4Settings = NEIPv4Settings(
                    addresses: ["10.0.0.2"],
                    subnetMasks: ["255.255.255.0"]
                )
                ipv4Settings.includedRoutes = [NEIPv4Route.default()]
                settings.ipv4Settings = ipv4Settings
                
                // DNS settings
                let dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
                settings.dnsSettings = dnsSettings
                
                // Apply settings
                try await setTunnelNetworkSettings(settings)
                
                // Start packet processing with TunnelManager
                tunnelManager = TunnelManager(
                    packetFlow: packetFlow,
                    rustCore: rustCore,
                    tunnelHandle: tunnelHandle,
                    mtu: 1500
                )
                tunnelManager?.onReconnect = { [weak self] in
                    self?.reconnectTunnel()
                }
                tunnelManager?.start()
                
                // Start UWB discovery (iPhone 11+, iOS 14+)
                if #available(iOS 14.0, *) {
                    startUWBDiscovery()
                }
                
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if #available(iOS 14.0, *) {
            (uwbDiscoveryManager as? UWBDiscoveryManager)?.stopDiscovery()
        }
        uwbDiscoveryManager = nil
        tunnelManager?.stop()
        tunnelManager = nil
        if let handle = tunnelHandle {
            rustCore?.stopTunnel(handle: handle)
            tunnelHandle = nil
        }
        rustCore = nil
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from main app
        // Used for status updates, configuration changes, etc.
        completionHandler?(nil)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Handle sleep - pause tunnel activity
        completionHandler()
    }
    
    override func wake() {
        // Handle wake - resume tunnel activity
    }
    
    // MARK: - Private Methods
    
    /// Load signed config pack from providerConfiguration, options, or fetch from API
    private func loadSignedConfigPack(options: [String: NSObject]?) async throws -> SignedConfigPack {
        // 1. Try providerConfiguration (main app saves config when creating VPN)
        if let proto = protocolConfiguration as? NETunnelProviderProtocol,
           let configData = proto.providerConfiguration?["config_pack"] as? Data,
           let config = try? JSONDecoder().decode(SignedConfigPackCodable.self, from: configData) {
            return config.toSignedConfigPack()
        }
        // 2. Try options (passed to startVPNTunnel)
        if let configData = options?["config_pack"] as? Data,
           let config = try? JSONDecoder().decode(SignedConfigPackCodable.self, from: configData) {
            return config.toSignedConfigPack()
        }
        if let configJson = options?["config_json"] as? String,
           let data = configJson.data(using: .utf8),
           let config = try? JSONDecoder().decode(SignedConfigPackCodable.self, from: data) {
            return config.toSignedConfigPack()
        }
        
        // 3. Fallback: fetch from API (extension can make network requests)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-unknown"
        let apiClient = TunnelApiClient()
        return try await apiClient.fetchConfig(deviceId: deviceId, region: "us-east-1")
    }
    
    /// Convert SignedConfigPack to JSON for Rust core
    private func configToJson(_ config: SignedConfigPack) -> String {
        var gatewaysArray: [[String: Any]] = []
        for gw in config.gateways {
            gatewaysArray.append([
                "id": gw.id,
                "address": gw.ipAddress,
                "port": gw.port,
                "transports": gw.transportTypes,
                "public_key": gw.publicKey.base64EncodedString()
            ])
        }
        let dict: [String: Any] = [
            "gateways": gatewaysArray,
            "transports": ["masque", "xtls"],
            "region": "us-east-1"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"gateways\":[],\"transports\":[\"masque\",\"xtls\"],\"region\":\"us-east-1\"}"
    }
    
    /// Perform DCAppAttest remote attestation
    @available(iOS 14.0, *)
    private func performAttestation() async throws -> Bool {
        let manager = DCAppAttestManager()
        return try await manager.performAttestation()
    }
    
    /// Reconnect tunnel on error (retry logic)
    private func reconnectTunnel() {
        tunnelManager?.stop()
        tunnelManager?.start()
    }
    
    /// Start UWB discovery (iPhone 11+, iOS 14+)
    @available(iOS 14.0, *)
    private func startUWBDiscovery() {
        let manager = UWBDiscoveryManager()
        uwbDiscoveryManager = manager
        manager.startDiscovery()
    }
}

/// Signed config pack data structure
struct SignedConfigPack {
    let gateways: [GatewayInfo]
    let signature: Data
    let timestamp: TimeInterval
}

/// Gateway information
struct GatewayInfo {
    let id: String
    let publicKey: Data
    let ipAddress: String
    let port: Int
    let transportTypes: [String]
}

// MARK: - Codable config for API/options
struct SignedConfigPackCodable: Codable {
    let version: String?
    let timestamp: Int64?
    let gateways: [GatewayInfoCodable]
    let signature: Data?
    let public_key: Data?
    
    func toSignedConfigPack() -> SignedConfigPack {
        SignedConfigPack(
            gateways: gateways.map { $0.toGatewayInfo() },
            signature: signature ?? Data(),
            timestamp: TimeInterval(timestamp ?? Int64(Date().timeIntervalSince1970))
        )
    }
}

struct GatewayInfoCodable: Codable {
    let id: String
    let address: String
    let port: Int
    let transports: [String]?
    let region: String?
    let public_key: Data?
    
    func toGatewayInfo() -> GatewayInfo {
        GatewayInfo(
            id: id,
            publicKey: public_key ?? Data(),
            ipAddress: address,
            port: port,
            transportTypes: transports ?? ["masque", "xtls"]
        )
    }
}

/// API client for tunnel extension (fetches config when main app doesn't pass it)
final class TunnelApiClient {
    private let baseURL = "https://api.lumenlink.org"
    private let session = URLSession.shared
    
    func fetchConfig(deviceId: String, region: String) async throws -> SignedConfigPack {
        guard let url = URL(string: "\(baseURL)/api/v1/config") else {
            throw NSError(domain: "TunnelApiClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "platform": "ios", "region": region]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "TunnelApiClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad response"])
        }
        let decoded = try JSONDecoder().decode(ConfigApiResponse.self, from: data)
        guard let pack = decoded.config_pack else {
            return SignedConfigPack(gateways: [], signature: Data(), timestamp: Date().timeIntervalSince1970)
        }
        return pack.toSignedConfigPack()
    }
}

struct ConfigApiResponse: Codable {
    let config_pack: ConfigPackApi?
}

struct ConfigPackApi: Codable {
    let version: String?
    let timestamp: Int64?
    let gateways: [GatewayInfoCodable]
    let signature: Data?
    let public_key: Data?
    
    func toSignedConfigPack() -> SignedConfigPack {
        SignedConfigPack(
            gateways: gateways.map { $0.toGatewayInfo() },
            signature: signature ?? Data(),
            timestamp: TimeInterval(timestamp ?? Int64(Date().timeIntervalSince1970))
        )
    }
}
