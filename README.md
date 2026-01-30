# LumenLink iOS Application

iOS VPN application for LumenLink using NetworkExtension.

**Website:** [lumenlink.org](https://lumenlink.org) · [Download](https://lumenlink.org/en/download) · [How-To Guide](https://lumenlink.org/en/how-to) · **API:** [api.lumenlink.org](https://api.lumenlink.org)

## Status

**Complete:** Full UI, Backend API, Discovery, PERSIA Mode, Emergency Contacts, Config fetch, Tunnel processing, UWB Discovery

## Architecture

```
LumenLink (Main App)
├── MainViewController, SettingsViewController
├── DiscoverySettingsViewController, PersiaModeViewController, EmergencyContactViewController
├── ApiClient, ConnectionStatusManager, DiscoveryManager, PersiaManager
└── OnboardingViewController, AppDelegate

LumenLinkPacketTunnel (Network Extension)
├── PacketTunnelProvider → TunnelManager → RustCore
├── DCAppAttestManager, UWBDiscoveryManager
└── lumenlink_ios.xcframework (Rust FFI)
```

## Implementation Details

### Full Feature Set ✅

- **UI:** Main (Connect/Disconnect), Settings (Discovery, PERSIA, Emergency), Onboarding
- **Backend API:** Config fetch from rendezvous, discovery log, getGateways
- **Config Flow:** Main app fetches config → passes via providerConfiguration → tunnel uses it
- **Discovery:** GPS, UWB, channel toggles, telemetry, scan
- **PERSIA Mode:** Enable/disable, credential exchange, bandwidth limit, data forwarding
- **Emergency:** Multiple contacts, panic mode, location updates, Siri integration
- **Tunnel:** TunnelManager packet loop, MTU handling, reconnect, UWB discovery

### Components

**1. PacketTunnelProvider** - Config from API/options, TunnelManager, UWB discovery
**2. TunnelManager** - Packet read/write loop, MTU, error recovery
**3. RustCore** - XCFramework bindings
**4. ApiClient** - getConfig, getConfigData, logDiscovery
**5. SettingsViewController** - Discovery, PERSIA, Emergency navigation

## Building

```bash
# 1. Generate Xcode project (requires XcodeGen: brew install xcodegen)
cd mobile/ios
xcodegen generate

# Or create project manually in Xcode:
# - File → New → Project → iOS App (LumenLink)
# - File → New → Target → Network Extension (LumenLinkPacketTunnel)
# - Add all Swift files to appropriate targets

# 2. Build Rust XCFramework
./scripts/build-xcframework.sh --release

# 3. Add lumenlink_ios.xcframework to LumenLinkPacketTunnel target in Xcode
# - Drag xcframework into project
# - Link Binary With Libraries

# 4. Build

# Build iOS app
cd mobile/ios
xcodebuild -scheme LumenLink -configuration Release
```

## Requirements

- iOS 14.0+ (for UWB support)
- Xcode 12+
- Rust toolchain
- NetworkExtension capability
- DCAppAttest capability

## Testing

```bash
# Run unit tests
xcodebuild test -scheme LumenLink

# Run on simulator
xcodebuild -scheme LumenLink -destination 'platform=iOS Simulator,name=iPhone 14'
```

## References

- [NetworkExtension Framework](https://developer.apple.com/documentation/networkextension)
- [DCAppAttestService](https://developer.apple.com/documentation/devicecheck/dcappattestservice)
- [NearbyInteraction Framework](https://developer.apple.com/documentation/nearbyinteraction)
