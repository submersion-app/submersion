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

# BLE connect-failure classification (issue #865): a dive computer whose
# pairing record has gone stale cannot be repaired from inside the app on Apple
# platforms, so the failure has to be recognised and handed to the user rather
# than retried.
swiftc -o "$BUILD_DIR/ble_connect_failure_tests" \
    Sources/LibDCDarwin/BleConnectFailure.swift \
    Tests/BleConnectFailureTests/main.swift

"$BUILD_DIR/ble_connect_failure_tests"

# Telit Terminal I/O credit accounting (issue #923). The OSTC4's BlueMod+SR
# module keeps its UART bridge closed until the client grants credits, and
# spends one per notification, so the balance has to be topped up mid-transfer.
swiftc -o "$BUILD_DIR/terminal_io_credit_policy_tests" \
    Sources/LibDCDarwin/TerminalIoCreditPolicy.swift \
    Tests/TerminalIoCreditPolicyTests/main.swift

"$BUILD_DIR/terminal_io_credit_policy_tests"

# SerialPortEnumerator pure-logic tests (USB-serial port classification and
# candidate selection for the Mares Puck Pro / serial-over-USB download path).
# -framework IOKit satisfies the IOKit references in enumerateUsbSerialPaths();
# the test itself only calls the pure functions.
swiftc -framework IOKit -o "$BUILD_DIR/serial_port_enumerator_tests" \
    Sources/LibDCDarwin/SerialPortEnumerator.swift \
    Tests/SerialPortEnumeratorTests/main.swift

"$BUILD_DIR/serial_port_enumerator_tests"

# serialReadFully accumulation tests (issue #334): the serial read must return
# exactly the requested byte count or time out, accumulating across the
# ~64-byte USB chunks that macOS USB-serial drivers deliver. Pure POSIX logic;
# a socketpair stands in for the serial fd.
swiftc -o "$BUILD_DIR/serial_read_loop_tests" \
    Sources/LibDCDarwin/SerialReadLoop.swift \
    Tests/SerialReadLoopTests/main.swift

"$BUILD_DIR/serial_read_loop_tests"

# SerialPortOpener errno-reporting tests (issue #291): open(2) failures must
# carry the real errno and an actionable reason, so a sandbox denial (EPERM) is
# distinguishable from a busy port or an unplugged cable. Pure POSIX logic.
swiftc -o "$BUILD_DIR/serial_port_opener_tests" \
    Sources/LibDCDarwin/SerialPortOpener.swift \
    Tests/SerialPortOpenerTests/main.swift

"$BUILD_DIR/serial_port_opener_tests"
