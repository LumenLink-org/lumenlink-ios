#!/bin/bash
# Build LumenLink Rust FFI as XCFramework for iOS
# Requires: rustup, xcode-select
#
# Usage: ./scripts/build-xcframework.sh [--release]
# Output: lumenlink_ios.xcframework in mobile/ios/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_FFI_DIR="$IOS_DIR/rust-ffi"
OUTPUT_DIR="$IOS_DIR"
RELEASE=""

if [[ "$1" == "--release" ]]; then
    RELEASE="--release"
fi

echo "=== LumenLink XCFramework Build ==="
echo "Rust FFI: $RUST_FFI_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Ensure iOS targets are installed
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-simulator 2>/dev/null || true

cd "$RUST_FFI_DIR"

# Build for device (arm64)
echo "Building for aarch64-apple-ios (device)..."
cargo build $RELEASE --target aarch64-apple-ios --lib 2>/dev/null || {
    echo "Note: aarch64-apple-ios may require Xcode. Trying without..."
    cargo build $RELEASE --target aarch64-apple-ios --lib
}

# Build for simulator (x86_64 - Intel Mac)
echo "Building for x86_64-apple-ios (simulator)..."
cargo build $RELEASE --target x86_64-apple-ios --lib 2>/dev/null || {
    cargo build $RELEASE --target x86_64-apple-ios --lib
}

# Build for simulator (arm64 - M1/M2 Mac)
echo "Building for aarch64-apple-ios-simulator..."
cargo build $RELEASE --target aarch64-apple-ios-simulator --lib 2>/dev/null || {
    cargo build $RELEASE --target aarch64-apple-ios-simulator --lib
}

# Create XCFramework
BUILD_DIR="target"
FRAMEWORK_NAME="lumenlink_ios"
XCFRAMEWORK_PATH="$OUTPUT_DIR/${FRAMEWORK_NAME}.xcframework"

# Remove existing XCFramework
rm -rf "$XCFRAMEWORK_PATH"

echo "Creating XCFramework..."

xcodebuild -create-xcframework \
    -library "$RUST_FFI_DIR/$BUILD_DIR/aarch64-apple-ios/$BUILD_SUFFIX/liblumenlink_ios.a" \
    -library "$RUST_FFI_DIR/$BUILD_DIR/x86_64-apple-ios/$BUILD_SUFFIX/liblumenlink_ios.a" \
    -library "$RUST_FFI_DIR/$BUILD_DIR/aarch64-apple-ios-simulator/$BUILD_SUFFIX/liblumenlink_ios.a" \
    -output "$XCFRAMEWORK_PATH"

echo ""
echo "=== Build complete ==="
echo "XCFramework: $XCFRAMEWORK_PATH"
ls -la "$XCFRAMEWORK_PATH"
