import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart';

/// Mock implementation of DiveComputerHostApi for testing.
class MockDiveComputerHostApi implements DiveComputerHostApi {
  DiscoveredDevice? lastDownloadDevice;
  String? lastDownloadFingerprint;

  @override
  Future<void> startDownload(
    DiscoveredDevice device,
    String? fingerprint,
  ) async {
    lastDownloadDevice = device;
    lastDownloadFingerprint = fingerprint;
  }

  @override
  Future<List<DeviceDescriptor>> getDeviceDescriptors() async => [];
  @override
  Future<void> startDiscovery(TransportType transport) async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> cancelDownload() async {}
  @override
  Future<String> getLibdivecomputerVersion() async => '0.0.0';
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

  group('serial transport download', () {
    test('startDownload passes serial transport device to host API', () async {
      final device = DiscoveredDevice(
        vendor: 'Cressi',
        product: 'Leonardo',
        model: 18,
        address: 'COM3',
        transport: TransportType.serial,
      );

      await service.startDownload(device);

      expect(mockHostApi.lastDownloadDevice?.vendor, 'Cressi');
      expect(mockHostApi.lastDownloadDevice?.product, 'Leonardo');
      expect(mockHostApi.lastDownloadDevice?.transport, TransportType.serial);
      expect(mockHostApi.lastDownloadDevice?.address, 'COM3');
    });

    test('startDownload passes USB transport device to host API', () async {
      final device = DiscoveredDevice(
        vendor: 'Cressi',
        product: 'Leonardo',
        model: 18,
        address: 'Cressi_Leonardo',
        transport: TransportType.usb,
      );

      await service.startDownload(device);

      expect(mockHostApi.lastDownloadDevice?.transport, TransportType.usb);
      expect(mockHostApi.lastDownloadDevice?.address, 'Cressi_Leonardo');
    });

    test('downloadEvents emits error for serial connection failure', () async {
      final error = DiveComputerError(
        code: 'connect_failed',
        message: 'Failed to open serial port',
      );

      final expectation = expectLater(
        service.downloadEvents,
        emits(isA<DownloadErrorEvent>()),
      );

      service.onError(error);

      await expectation;
    });
  });
}
