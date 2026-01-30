//
//  RustCoreTests.swift
//  LumenLinkPacketTunnelTests
//
//  Unit tests for Rust core Swift bindings.
//  Add this file to LumenLinkPacketTunnelTests target in Xcode.
//

import XCTest
@testable import LumenLinkPacketTunnel

final class RustCoreTests: XCTestCase {

    func testRustCoreStartStopTunnel() throws {
        let config = SignedConfigPack(
            gateways: [],
            signature: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        let rustCore = try RustCore(config: config)
        let configJson = "{\"gateways\":[],\"transports\":[\"masque\",\"xtls\"],\"region\":\"us-east-1\"}"
        let handle = rustCore.startTunnel(configJson: configJson)
        XCTAssertNotNil(handle)
        if let h = handle {
            rustCore.stopTunnel(handle: h)
        }
    }

    func testRustCoreGetStatistics() throws {
        let config = SignedConfigPack(
            gateways: [],
            signature: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        let rustCore = try RustCore(config: config)
        let configJson = "{}"
        _ = rustCore.startTunnel(configJson: configJson)
        let stats = rustCore.getStatistics()
        XCTAssertFalse(stats.isEmpty)
        XCTAssertNotNil(stats["bytes_sent"])
        XCTAssertNotNil(stats["bytes_received"])
    }

    func testRustCoreHandlePacket() throws {
        let config = SignedConfigPack(
            gateways: [],
            signature: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        let rustCore = try RustCore(config: config)
        _ = rustCore.startTunnel(configJson: "{}")
        let packet = Data([0x45, 0x00, 0x00, 0x14]) // Minimal IP header
        let response = rustCore.handlePacket(packet, protocol: NSNumber(value: 2)) // AF_INET
        // Rust FFI returns nil for now (no response packet)
        XCTAssertNil(response)
    }

    func testRustCoreEnableGatewayMode() throws {
        let config = SignedConfigPack(
            gateways: [],
            signature: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        let rustCore = try RustCore(config: config)
        rustCore.enableGatewayMode(bandwidthLimit: 100)
        rustCore.disableGatewayMode()
    }
}
