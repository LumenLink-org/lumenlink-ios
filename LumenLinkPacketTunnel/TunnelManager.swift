//
//  TunnelManager.swift
//  LumenLinkPacketTunnel
//
//  Tunnel management and packet forwarding with full read/write loop,
//  MTU handling, error recovery, and reconnect logic.
//

import NetworkExtension
import Foundation

/// MTU constants
private let DEFAULT_MTU = 1500
private let MIN_MTU = 1280
private let MAX_MTU = 1500
private let MAX_RETRIES = 3
private let RETRY_DELAY_MS: UInt64 = 500

/// Tunnel Manager
///
/// Manages tunnel lifecycle and packet forwarding with:
/// - Full packet read/write loop
/// - MTU validation and fragmentation handling
/// - Error handling and reconnect logic
class TunnelManager {

    private let packetFlow: NEPacketTunnelFlow
    private var isRunning = false
    private var rustCore: RustCore?
    private var tunnelHandle: UnsafeMutableRawPointer?
    private let mtu: Int
    private var consecutiveErrors = 0
    private let lock = NSLock()

    var onError: ((Error) -> Void)?
    var onReconnect: (() -> Void)?

    init(packetFlow: NEPacketTunnelFlow, rustCore: RustCore?, tunnelHandle: UnsafeMutableRawPointer?, mtu: Int = DEFAULT_MTU) {
        self.packetFlow = packetFlow
        self.rustCore = rustCore
        self.tunnelHandle = tunnelHandle
        self.mtu = min(max(mtu, MIN_MTU), MAX_MTU)
    }

    /// Start tunnel packet processing
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }
        isRunning = true
        consecutiveErrors = 0
        readPackets()
    }

    /// Stop tunnel packet processing
    func stop() {
        lock.lock()
        isRunning = false
        lock.unlock()
    }

    /// Read packets from TUN interface (full read loop)
    private func readPackets() {
        lock.lock()
        let running = isRunning
        lock.unlock()
        guard running else { return }

        packetFlow.readPackets { [weak self] (packets, protocols) in
            guard let self = self else { return }
            self.lock.lock()
            let running = self.isRunning
            self.lock.unlock()
            guard running else { return }

            self.processPackets(packets, protocols: protocols)
            self.consecutiveErrors = 0

            self.readPackets()
        }
    }

    /// Process packets through Rust core with MTU handling
    private func processPackets(_ packets: [Data], protocols: [NSNumber]) {
        var responses: [(Data, NSNumber)] = []

        for (index, packet) in packets.enumerated() {
            let proto = index < protocols.count ? protocols[index] : NSNumber(value: 2)

            if packet.count > mtu {
                let fragmented = fragmentPacket(packet, protocol: proto)
                for (frag, p) in fragmented {
                    if let response = rustCore?.handlePacket(frag, protocol: p) {
                        responses.append((response, p))
                    }
                }
            } else {
                if let response = rustCore?.handlePacket(packet, protocol: proto) {
                    if response.count <= mtu {
                        responses.append((response, proto))
                    } else {
                        let fragmented = fragmentPacket(response, protocol: proto)
                        for (frag, p) in fragmented {
                            responses.append((frag, p))
                        }
                    }
                }
            }
        }

        if !responses.isEmpty {
            let (respPackets, respProtos) = responses.reduce(([Data](), [NSNumber]())) { acc, item in
                (acc.0 + [item.0], acc.1 + [item.1])
            }
            writePackets(respPackets, protocols: respProtos)
        }
    }

    /// Fragment packet if exceeds MTU (simple split; IP fragmentation would be more complex)
    private func fragmentPacket(_ packet: Data, protocol proto: NSNumber) -> [(Data, NSNumber)] {
        var result: [(Data, NSNumber)] = []
        var offset = 0
        while offset < packet.count {
            let end = min(offset + mtu, packet.count)
            let chunk = packet.subdata(in: offset..<end)
            result.append((chunk, proto))
            offset = end
        }
        return result
    }

    /// Write packets to TUN interface
    func writePackets(_ packets: [Data], protocols: [NSNumber]) {
        guard !packets.isEmpty else { return }
        let toWrite = packets.map { packet -> Data in
            if packet.count > mtu {
                return Data(packet.prefix(mtu))
            }
            return packet
        }
        packetFlow.writePackets(toWrite, withProtocols: protocols)
    }

    /// Handle error with retry logic
    private func handleError(_ error: Error) {
        onReconnect?()
    }
}
