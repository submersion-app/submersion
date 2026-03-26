import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_notifier_fingerprint_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;
  late DownloadNotifier notifier;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();

    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());

    notifier = DownloadNotifier(
      service: mockService,
      repository: mockRepository,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('fingerprint logic in startDownload', () {
    test('newDivesOnly defaults to true', () {
      expect(notifier.state.newDivesOnly, isTrue);
    });

    test('setNewDivesOnly updates state', () {
      notifier.setNewDivesOnly(false);
      expect(notifier.state.newDivesOnly, isFalse);

      notifier.setNewDivesOnly(true);
      expect(notifier.state.newDivesOnly, isTrue);
    });
  });

  group('error event sets errorCode', () {
    test('DownloadErrorEvent populates errorCode in state', () async {
      final controller = StreamController<DownloadEvent>.broadcast();
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);

      final testNotifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );

      final device = DiscoveredDevice(
        id: 'test-1',
        name: 'Test Device',
        connectionType: DeviceConnectionType.usb,
        address: 'COM3',
        discoveredAt: DateTime(2026, 1, 1),
      );

      when(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).thenAnswer((_) async {});

      await testNotifier.startDownload(device);

      controller.add(
        DownloadErrorEvent(
          DiveComputerError(code: 'no_serial_ports', message: 'No ports'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(testNotifier.state.errorCode, 'no_serial_ports');
      expect(testNotifier.state.errorMessage, 'No ports');
      expect(testNotifier.state.phase, DownloadPhase.error);

      testNotifier.dispose();
      await controller.close();
    });
  });
}
