//
//  ChannelResult.swift
//  LumenLink
//
//  Result of a discovery channel scan.
//

import Foundation

struct ChannelResult {
    let channel: DiscoveryChannel
    let success: Bool
    let gatewaysFound: Int
    let latencyMs: Int?
    let errorMessage: String?
    let timestamp: Date

    init(channel: DiscoveryChannel, success: Bool, gatewaysFound: Int = 0, latencyMs: Int? = nil, errorMessage: String? = nil, timestamp: Date = Date()) {
        self.channel = channel
        self.success = success
        self.gatewaysFound = gatewaysFound
        self.latencyMs = latencyMs
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
}
