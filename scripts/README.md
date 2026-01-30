# LumenLink iOS Build Scripts

**Website:** [lumenlink.org](https://lumenlink.org) · [Download](https://lumenlink.org/en/download) · [How-To](https://lumenlink.org/en/how-to) · **API:** [api.lumenlink.org](https://api.lumenlink.org)

## XCFramework Build

Build the Rust FFI as XCFramework for iOS:

```bash
# From mobile/ios/
./scripts/build-xcframework.sh --release
```

This will:
1. Build `lumenlink-ios-ffi` for:
   - `aarch64-apple-ios` (device)
   - `x86_64-apple-ios` (simulator, Intel Mac)
   - `aarch64-apple-ios-simulator` (simulator, M1/M2 Mac)
2. Create `lumenlink_ios.xcframework` in `mobile/ios/`

### Prerequisites

- Rust toolchain (`rustup`)
- Xcode (for `xcodebuild` and iOS SDK)
- iOS targets: `rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-simulator`

### Rust FFI Tests

```bash
cd mobile/ios/rust-ffi
cargo test
```

## Xcode Project Setup

1. Create new Xcode project (or open existing)
2. Add `lumenlink_ios.xcframework` to the project:
   - Drag the .xcframework into Xcode
   - Or: Target → General → Frameworks → + → Add Other → lumenlink_ios.xcframework
3. Ensure "Embed & Sign" or "Do Not Embed" as appropriate for static lib
4. For Packet Tunnel extension target, link lumenlink_ios.xcframework

## Symbol Visibility

The Rust FFI exports C ABI symbols with `#[no_mangle] pub extern "C"`:
- `lumenlink_start_tunnel`
- `lumenlink_stop_tunnel`
- `lumenlink_handle_packet`
- `lumenlink_get_statistics`
- `lumenlink_free_string`
- `lumenlink_enable_gateway_mode`
- `lumenlink_disable_gateway_mode`

These are resolved at link time when the XCFramework is linked.
