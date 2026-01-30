//
//  DiscoveryChannel.swift
//  LumenLink
//
//  Discovery channel types.
//

import Foundation

enum DiscoveryChannel: String, CaseIterable {
    case gps = "gps"
    case fmRds = "fm_rds"
    case dtv = "dtv"
    case plc = "plc"
    case gsm = "gsm"
    case lte = "lte"
    case blockchain = "blockchain"
    case iot = "iot"
    case satellite = "satellite"
    case uwb = "uwb"

    var displayName: String {
        switch self {
        case .gps: return "GPS/GNSS"
        case .fmRds: return "FM RDS"
        case .dtv: return "Digital TV"
        case .plc: return "Power Line"
        case .gsm: return "GSM Cell Broadcast"
        case .lte: return "LTE/NR SIB"
        case .blockchain: return "Blockchain"
        case .iot: return "IoT (MQTT/CoAP)"
        case .satellite: return "Satellite"
        case .uwb: return "UWB"
        }
    }

    var requiresPermission: String? {
        switch self {
        case .gps, .uwb: return "Location"
        default: return nil
        }
    }
}
