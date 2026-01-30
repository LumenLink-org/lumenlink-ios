//
//  DiscoveryManager.swift
//  LumenLink
//
//  Manages discovery channel selection and telemetry.
//

import Foundation
import Combine

final class DiscoveryManager {
    private let gpsService = GpsDiscoveryService()
    @Published private(set) var enabledChannels: Set<DiscoveryChannel> = [.gps]
    @Published private(set) var channelResults: [ChannelResult] = []

    func setChannelEnabled(_ channel: DiscoveryChannel, enabled: Bool) {
        if enabled {
            enabledChannels.insert(channel)
        } else {
            enabledChannels.remove(channel)
        }
    }

    func isChannelEnabled(_ channel: DiscoveryChannel) -> Bool {
        enabledChannels.contains(channel)
    }

    func scanChannels(onResult: ((ChannelResult) -> Void)? = nil) {
        guard !enabledChannels.isEmpty else { return }

        if enabledChannels.contains(.gps) {
            gpsService.startDiscovery { [weak self] result in
                self?.recordResult(result)
                onResult?(result)
            }
        }

        for channel in enabledChannels where channel != .gps {
            let result = ChannelResult(channel: channel, success: false, errorMessage: "Not implemented")
            recordResult(result)
            onResult?(result)
        }
    }

    func recordResult(_ result: ChannelResult) {
        channelResults.append(result)
    }

    func getSuccessRate(for channel: DiscoveryChannel) -> Float {
        let results = channelResults.filter { $0.channel == channel }
        guard !results.isEmpty else { return 0 }
        return Float(results.filter { $0.success }.count) / Float(results.count)
    }

    func getLastResult(for channel: DiscoveryChannel) -> ChannelResult? {
        channelResults.filter { $0.channel == channel }.max(by: { $0.timestamp < $1.timestamp })
    }
}
