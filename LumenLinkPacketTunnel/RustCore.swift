//
//  RustCore.swift
//  LumenLinkPacketTunnel
//
//  Rust Core XCFramework bindings - Swift interface to lumenlink_ios C FFI.
//  Links against lumenlink_ios.xcframework (built from rust-ffi crate).
//

import Foundation

// MARK: - C FFI imports (resolved from lumenlink_ios.xcframework at link time)

@_silgen_name("lumenlink_start_tunnel")
private func _lumenlink_start_tunnel(_ config_json: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?

@_silgen_name("lumenlink_stop_tunnel")
private func _lumenlink_stop_tunnel(_ handle: UnsafeMutableRawPointer?)

@_silgen_name("lumenlink_handle_packet")
private func _lumenlink_handle_packet(
    _ handle: UnsafeMutableRawPointer?,
    _ packet: UnsafePointer<UInt8>?,
    _ packet_len: Int32,
    _ response_out: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ response_len_out: UnsafeMutablePointer<Int32>?
) -> Int32

@_silgen_name("lumenlink_get_statistics")
private func _lumenlink_get_statistics(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("lumenlink_free_string")
private func _lumenlink_free_string(_ s: UnsafeMutablePointer<CChar>?)

@_silgen_name("lumenlink_enable_gateway_mode")
private func _lumenlink_enable_gateway_mode(_ bandwidth_limit_mbps: Int32)

@_silgen_name("lumenlink_disable_gateway_mode")
private func _lumenlink_disable_gateway_mode()

// MARK: - RustCore Swift API

/// Rust Core XCFramework Interface
///
/// Provides Swift interface to Rust core library via XCFramework.
class RustCore {

    private var handle: UnsafeMutableRawPointer?

    init(config: SignedConfigPack) throws {
        // Config will be used when starting tunnel
    }

    deinit {
        if let handle = handle {
            _lumenlink_stop_tunnel(handle)
        }
    }

    /// Start tunnel with config JSON
    func startTunnel(configJson: String) -> UnsafeMutableRawPointer? {
        let handle = configJson.withCString { ptr in
            _lumenlink_start_tunnel(ptr)
        }
        self.handle = handle
        return handle
    }

    /// Stop tunnel
    func stopTunnel(handle: UnsafeMutableRawPointer) {
        _lumenlink_stop_tunnel(handle)
        if self.handle == handle {
            self.handle = nil
        }
    }

    /// Handle packet from TUN interface
    func handlePacket(_ packet: Data, protocol: NSNumber) -> Data? {
        guard let handle = handle else { return nil }
        return packet.withUnsafeBytes { (packetPtr: UnsafeRawBufferPointer) -> Data? in
            guard let baseAddress = packetPtr.baseAddress else { return nil }
            var responsePtr: UnsafeMutablePointer<UInt8>?
            var responseLen: Int32 = 0
            let result = _lumenlink_handle_packet(
                handle,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                Int32(packet.count),
                &responsePtr,
                &responseLen
            )
            guard result == 0, let respPtr = responsePtr, responseLen > 0 else {
                return nil
            }
            return Data(bytes: respPtr, count: Int(responseLen))
        }
    }

    /// Get tunnel statistics as dictionary
    func getStatistics() -> [String: Any] {
        guard let handle = handle else { return [:] }
        guard let statsPtr = _lumenlink_get_statistics(handle) else { return [:] }
        defer { _lumenlink_free_string(statsPtr) }
        let jsonString = String(cString: statsPtr)
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// Enable gateway mode (PERSIA mode)
    func enableGatewayMode(bandwidthLimit: Int) {
        _lumenlink_enable_gateway_mode(Int32(bandwidthLimit))
    }

    /// Disable gateway mode
    func disableGatewayMode() {
        _lumenlink_disable_gateway_mode()
    }
}
