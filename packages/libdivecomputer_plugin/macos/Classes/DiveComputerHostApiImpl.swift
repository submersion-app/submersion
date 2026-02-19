import FlutterMacOS

class DiveComputerHostApiImpl: DiveComputerHostApi {
    private let messenger: FlutterBinaryMessenger
    private let flutterApi: DiveComputerFlutterApi

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        self.flutterApi = DiveComputerFlutterApi(binaryMessenger: messenger)
    }

    func getDeviceDescriptors(completion: @escaping (Result<[DeviceDescriptor], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var descriptors: [DeviceDescriptor] = []

            guard let iter = libdc_descriptor_iterator_new() else {
                completion(.success([]))
                return
            }

            var info = libdc_descriptor_info_t()
            while libdc_descriptor_iterator_next(iter, &info) == 0 {
                let vendor = info.vendor.map { String(cString: $0) } ?? ""
                let product = info.product.map { String(cString: $0) } ?? ""
                let transports = Self.mapTransports(info.transports)

                descriptors.append(DeviceDescriptor(
                    vendor: vendor,
                    product: product,
                    model: Int64(info.model),
                    transports: transports
                ))
            }

            libdc_descriptor_iterator_free(iter)
            completion(.success(descriptors))
        }
    }

    private static func mapTransports(_ bitmask: UInt32) -> [TransportType] {
        var transports: [TransportType] = []
        if bitmask & UInt32(LIBDC_TRANSPORT_BLE) != 0 {
            transports.append(.ble)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_USB) != 0 ||
           bitmask & UInt32(LIBDC_TRANSPORT_USBHID) != 0 {
            transports.append(.usb)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_SERIAL) != 0 {
            transports.append(.serial)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_IRDA) != 0 {
            transports.append(.infrared)
        }
        return transports
    }

    func startDiscovery(transport: TransportType, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement with dc_bluetooth_enumerate or dc_ble_enumerate
        completion(.success(()))
    }

    func stopDiscovery() throws {
        // TODO: Stop discovery
    }

    func startDownload(device: DiscoveredDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement download lifecycle
        completion(.success(()))
    }

    func cancelDownload() throws {
        // TODO: Cancel download
    }

    func getLibdivecomputerVersion() throws -> String {
        guard let versionPtr = libdc_get_version() else {
            return "unknown"
        }
        return String(cString: versionPtr)
    }
}
