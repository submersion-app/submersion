import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart';

/// Mock implementation of DiveComputerHostApi for testing.
///
/// Since Pigeon generates DiveComputerHostApi as a concrete class with
/// channel internals, we implement its public method interface directly.
class MockDiveComputerHostApi implements DiveComputerHostApi {
  List<DeviceDescriptor> descriptorsToReturn = [];
  String versionToReturn = '0.0.0';
  bool startDiscoveryCalled = false;
  bool stopDiscoveryCalled = false;
  bool startDownloadCalled = false;
  bool cancelDownloadCalled = false;
  TransportType? lastDiscoveryTransport;
  DiscoveredDevice? lastDownloadDevice;

  @override
  Future<List<DeviceDescriptor>> getDeviceDescriptors() async {
    return descriptorsToReturn;
  }

  @override
  Future<void> startDiscovery(TransportType transport) async {
    startDiscoveryCalled = true;
    lastDiscoveryTransport = transport;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalled = true;
  }

  @override
  Future<void> startDownload(DiscoveredDevice device) async {
    startDownloadCalled = true;
    lastDownloadDevice = device;
  }

  @override
  Future<void> cancelDownload() async {
    cancelDownloadCalled = true;
  }

  @override
  Future<String> getLibdivecomputerVersion() async {
    return versionToReturn;
  }

  // Required by implements but not used in tests
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockDiveComputerHostApi mockHostApi;
  late DiveComputerService service;

  setUp(() {
    mockHostApi = MockDiveComputerHostApi();
    service = DiveComputerService(hostApi: mockHostApi);
  });

  tearDown(() {
    service.dispose();
  });

  group('getDeviceDescriptors', () {
    test('returns device descriptors from host API', () async {
      mockHostApi.descriptorsToReturn = [
        DeviceDescriptor(
          vendor: 'Shearwater',
          product: 'Perdix',
          model: 1,
          transports: [TransportType.ble],
        ),
      ];

      final descriptors = await service.getDeviceDescriptors();

      expect(descriptors, hasLength(1));
      expect(descriptors.first.vendor, 'Shearwater');
      expect(descriptors.first.product, 'Perdix');
    });
  });

  group('getVersion', () {
    test('returns libdivecomputer version', () async {
      mockHostApi.versionToReturn = '0.8.0';
      final version = await service.getVersion();
      expect(version, '0.8.0');
    });
  });

  group('discovery', () {
    test('startDiscovery calls host API with transport', () async {
      await service.startDiscovery(TransportType.ble);
      expect(mockHostApi.startDiscoveryCalled, isTrue);
      expect(mockHostApi.lastDiscoveryTransport, TransportType.ble);
    });

    test('stopDiscovery calls host API', () async {
      await service.stopDiscovery();
      expect(mockHostApi.stopDiscoveryCalled, isTrue);
    });

    test('discoveredDevices stream emits devices', () async {
      final device = DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 1,
        address: '00:11:22:33:44:55',
        name: 'Perdix 12345',
        transport: TransportType.ble,
      );

      expectLater(service.discoveredDevices, emits(device));

      service.onDeviceDiscovered(device);
    });

    test('discoveryComplete stream emits on completion', () async {
      expectLater(service.discoveryComplete, emitsInOrder([null]));

      service.onDiscoveryComplete();
    });
  });

  group('download', () {
    test('startDownload calls host API', () async {
      final device = DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 1,
        address: '00:11:22:33:44:55',
        transport: TransportType.ble,
      );

      await service.startDownload(device);
      expect(mockHostApi.startDownloadCalled, isTrue);
      expect(mockHostApi.lastDownloadDevice?.vendor, 'Shearwater');
    });

    test('cancelDownload calls host API', () async {
      await service.cancelDownload();
      expect(mockHostApi.cancelDownloadCalled, isTrue);
    });

    test('downloadEvents stream emits progress', () async {
      final progress = DownloadProgress(
        current: 1,
        total: 5,
        status: 'Downloading dive 1 of 5',
      );

      expectLater(service.downloadEvents, emits(isA<DownloadProgressEvent>()));

      service.onDownloadProgress(progress);
    });

    test('downloadEvents stream emits dives', () async {
      final dive = ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.0,
        durationSeconds: 3600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      expectLater(service.downloadEvents, emits(isA<DiveDownloadedEvent>()));

      service.onDiveDownloaded(dive);
    });

    test('downloadEvents stream emits completion', () async {
      expectLater(service.downloadEvents, emits(isA<DownloadCompleteEvent>()));

      service.onDownloadComplete(5, null, null);
    });

    test('downloadEvents stream emits errors', () async {
      final error = DiveComputerError(
        code: 'timeout',
        message: 'Connection timed out',
      );

      expectLater(service.downloadEvents, emits(isA<DownloadErrorEvent>()));

      service.onError(error);
    });
  });
}
