import CoreBluetooth
import Foundation

/// Scans for BLE dive computers using CoreBluetooth and matches discovered
/// peripherals against libdivecomputer's descriptor database.
class BleScanner: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var isScanning = false
    private var seenIdentifiers = Set<UUID>()
    private let queue = DispatchQueue(label: "com.submersion.ble-scanner", qos: .userInitiated)

    var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?
    var onComplete: (() -> Void)?

    private static func isAsciiLetter(_ scalar: UnicodeScalar) -> Bool {
        return (scalar.value >= 65 && scalar.value <= 90) ||
            (scalar.value >= 97 && scalar.value <= 122)
    }

    private static func isAsciiDigit(_ scalar: UnicodeScalar) -> Bool {
        return scalar.value >= 48 && scalar.value <= 57
    }

    private static func isNameSeparator(_ scalar: UnicodeScalar) -> Bool {
        return scalar.value == 32 || scalar.value == 45 || scalar.value == 95
    }

    private static func asciiUpper(_ scalar: UnicodeScalar) -> UInt32 {
        if scalar.value >= 97 && scalar.value <= 122 {
            return scalar.value - 32
        }
        return scalar.value
    }

    /// Pelagic BLE names are typically two letters + serial digits (e.g. FH025918).
    private static func parsePelagicModelCode(from name: String) -> UInt32? {
        let scalars = Array(name.unicodeScalars)
        guard scalars.count >= 8 else { return nil }
        let s0 = scalars[0]
        let s1 = scalars[1]
        guard isAsciiLetter(s0), isAsciiLetter(s1) else { return nil }

        var digits = 0
        for scalar in scalars.dropFirst(2) {
            if isAsciiDigit(scalar) {
                digits += 1
                continue
            }
            if isNameSeparator(scalar) {
                continue
            }
            return nil
        }
        guard digits >= 6 else { return nil }

        let c0 = asciiUpper(s0)
        let c1 = asciiUpper(s1)
        return (c0 << 8) | c1
    }

    func start() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.seenIdentifiers.removeAll()
            self.centralManager = CBCentralManager(delegate: self, queue: self.queue)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                self.centralManager?.stopScan()
                self.isScanning = false
            }
            self.onComplete?()
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("[BleScanner] Starting BLE scan")
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            isScanning = true
        case .poweredOff, .unauthorized, .unsupported:
            isScanning = false
            NSLog("[BleScanner] Scan unavailable (state=%ld)", central.state.rawValue)
            onComplete?()
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !seenIdentifiers.contains(peripheral.identifier) else { return }
        guard let name = peripheral.name ??
              advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return
        }

        var info = libdc_descriptor_info_t()
        var matched: Int32 = 0

        // For Pelagic serial-style names, prefer exact model lookup first.
        if let modelCode = Self.parsePelagicModelCode(from: name) {
            matched = libdc_descriptor_lookup_model(UInt32(LIBDC_TRANSPORT_BLE), modelCode, &info)
            if matched != 0 {
                NSLog("[BleScanner] Model-code matched %@ as 0x%04x",
                      name, modelCode)
            }
        }

        if matched == 0 {
            matched = name.withCString { namePtr -> Int32 in
                libdc_descriptor_match(namePtr, UInt32(LIBDC_TRANSPORT_BLE), &info)
            }
        }

        guard matched != 0 else {
            NSLog("[BleScanner] Unmatched peripheral %@ (%@)",
                  peripheral.identifier.uuidString, name)
            return
        }
        seenIdentifiers.insert(peripheral.identifier)
        NSLog("[BleScanner] Matched peripheral %@ (%@) -> %@ %@ (%u)",
              peripheral.identifier.uuidString, name,
              String(cString: info.vendor),
              String(cString: info.product),
              info.model)

        let device = DiscoveredDevice(
            vendor: String(cString: info.vendor),
            product: String(cString: info.product),
            model: Int64(info.model),
            address: peripheral.identifier.uuidString,
            name: name,
            transport: .ble
        )

        onDeviceDiscovered?(device)
    }
}
