//
//  TunnelManager.swift
//  LumenLinkPacketTunnel
//
//  Tunnel management and packet forwarding
//

import NetworkExtension
import Foundation

/// Tunnel Manager
/// 
/// Manages tunnel lifecycle and packet forwarding.
class TunnelManager {
    
    private let packetFlow: NEPacketTunnelFlow
    private var isRunning = false
    
    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }
    
    /// Start tunnel packet processing
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        readPackets()
    }
    
    /// Stop tunnel packet processing
    func stop() {
        isRunning = false
    }
    
    /// Read packets from TUN interface
    private func readPackets() {
        guard isRunning else { return }
        
        packetFlow.readPackets { [weak self] (packets, protocols) in
            guard let self = self, self.isRunning else { return }
            
            // Process packets
            self.processPackets(packets, protocols: protocols)
            
            // Continue reading
            self.readPackets()
        }
    }
    
    /// Process packets
    private func processPackets(_ packets: [Data], protocols: [NSNumber]) {
        // TODO: Process packets through Rust core
        // - Parse IP packets
        // - Forward through transport layer
        // - Write responses back
    }
    
    /// Write packets to TUN interface
    func writePackets(_ packets: [Data], protocols: [NSNumber]) {
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}
