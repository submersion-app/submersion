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
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            isScanning = true
        case .poweredOff, .unauthorized, .unsupported:
            isScanning = false
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
        let matched = name.withCString { namePtr in
            libdc_descriptor_match(namePtr, UInt32(LIBDC_TRANSPORT_BLE), &info)
        }

        guard matched != 0 else { return }
        seenIdentifiers.insert(peripheral.identifier)

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
