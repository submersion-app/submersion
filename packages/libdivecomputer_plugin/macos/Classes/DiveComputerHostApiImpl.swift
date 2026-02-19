import FlutterMacOS

class DiveComputerHostApiImpl: DiveComputerHostApi {
    private let messenger: FlutterBinaryMessenger
    private let flutterApi: DiveComputerFlutterApi

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        self.flutterApi = DiveComputerFlutterApi(binaryMessenger: messenger)
    }

    func getDeviceDescriptors(completion: @escaping (Result<[DeviceDescriptor], Error>) -> Void) {
        // TODO: Implement with dc_descriptor_iterator
        completion(.success([]))
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
        return "0.0.0-stub"
    }
}
