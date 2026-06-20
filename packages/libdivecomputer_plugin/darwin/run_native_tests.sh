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

swiftc -o "$BUILD_DIR/ble_characteristic_selector_tests" \
    Sources/LibDCDarwin/BleCharacteristicSelector.swift \
    Tests/BleCharacteristicSelectorTests/main.swift

"$BUILD_DIR/ble_characteristic_selector_tests"

# SerialPortEnumerator pure-logic tests (USB-serial port classification and
# candidate selection for the Mares Puck Pro / serial-over-USB download path).
# -framework IOKit satisfies the IOKit references in enumerateUsbSerialPaths();
# the test itself only calls the pure functions.
swiftc -framework IOKit -o "$BUILD_DIR/serial_port_enumerator_tests" \
    Sources/LibDCDarwin/SerialPortEnumerator.swift \
    Tests/SerialPortEnumeratorTests/main.swift

"$BUILD_DIR/serial_port_enumerator_tests"
