//
//  PersiaDataForwarder.swift
//  LumenLink
//
//  PERSIA Mode data forwarding path.
//

import Foundation
import Combine

final class PersiaDataForwarder {
    private let persiaManager: PersiaManager
    private var task: Task<Void, Never>?

    @Published private(set) var bytesForwarded: Int64 = 0

    init(persiaManager: PersiaManager = .shared) {
        self.persiaManager = persiaManager
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled, self?.persiaManager.isEnabled == true {
                self?.persiaManager.updateConnectedPeers(self?.persiaManager.connectedPeers ?? 0)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func forwardFromPeer(peerId: String, packet: Data) {
        guard persiaManager.isEnabled else { return }
        bytesForwarded += Int64(packet.count)
    }

    func forwardToPeer(peerId: String, packet: Data) {
        guard persiaManager.isEnabled else { return }
        bytesForwarded += Int64(packet.count)
    }
}
