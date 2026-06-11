#!/bin/bash
# Compiles and runs the standalone native unit tests for the darwin BLE
# transport helpers. These cannot run under `swift test` because the
# LibDCDarwin SwiftPM target depends on Flutter modules that only exist in
# the CocoaPods build.
set -euo pipefail

cd "$(dirname "$0")"

BUILD_DIR=".build/native-tests"
mkdir -p "$BUILD_DIR"

swiftc -o "$BUILD_DIR/packet_read_buffer_tests" \
    Sources/LibDCDarwin/PacketReadBuffer.swift \
    Tests/PacketReadBufferTests/main.swift

"$BUILD_DIR/packet_read_buffer_tests"
