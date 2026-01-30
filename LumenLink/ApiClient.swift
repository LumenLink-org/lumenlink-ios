//
//  ApiClient.swift
//  LumenLink
//
//  Rendezvous backend API client.
//

import Foundation

final class ApiClient {
    static let shared = ApiClient()
    private let baseURL = "https://api.lumenlink.org"
    private let session = URLSession.shared

    private init() {}

    func getConfig(deviceId: String, region: String? = nil) async throws -> ConfigPack {
        guard let url = URL(string: "\(baseURL)/api/v1/config") else { throw NSError(domain: "ApiClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "platform": "ios", "region": region ?? "us-east-1"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NSError(domain: "ApiClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad response"]) }
        let decoded = try JSONDecoder().decode(ConfigResponse.self, from: data)
        return decoded.config_pack ?? ConfigPack(gateways: [], transports: nil, region: "us-east-1")
    }

    /// Fetch raw config pack data for passing to VPN tunnel (matches backend SignedConfigPack)
    func getConfigData(deviceId: String, region: String? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/v1/config") else { throw NSError(domain: "ApiClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "platform": "ios", "region": region ?? "us-east-1"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return data
    }

    func logDiscovery(channelType: String, success: Bool, latencyMs: Int? = nil, error: String? = nil) async {
        guard let url = URL(string: "\(baseURL)/api/v1/discovery/log") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["channel_type": channelType, "success": success]
        if let lat = latencyMs { body["latency_ms"] = lat }
        if let err = error { body["error"] = err }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }
}

struct ConfigResponse: Codable { let config_pack: ConfigPack? }
struct ConfigPack: Codable {
    let gateways: [GatewayInfo]
    let transports: [TransportConfig]?
    let region: String?
    init(gateways: [GatewayInfo], transports: [TransportConfig]?, region: String?) {
        self.gateways = gateways
        self.transports = transports
        self.region = region
    }
}
struct GatewayInfo: Codable { let id: String; let address: String; let port: Int; let transports: [String]; let region: String? }
struct TransportConfig: Codable { let type: String; let endpoints: [String]? }
