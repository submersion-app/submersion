import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
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

  group('download failures are logged', () {
    test('DownloadErrorEvent writes an ERROR log entry', () async {
      final controller = StreamController<DownloadEvent>.broadcast();
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);
      when(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).thenAnswer((_) async {});

      final testNotifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );

      final errorEntries = <LogEntry>[];
      final sub = LoggerService.logStream
          .where((e) => e.level == LogLevel.error)
          .listen(errorEntries.add);

      final device = DiscoveredDevice(
        id: 'test-err-1',
        name: 'Test Device',
        connectionType: DeviceConnectionType.ble,
        address: '00:11:22:33:44:55',
        discoveredAt: DateTime(2026, 1, 1),
      );

      await testNotifier.startDownload(device);

      controller.add(
        DownloadErrorEvent(
          DiveComputerError(
            code: 'comm_timeout',
            message: 'Communication timeout',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(errorEntries, hasLength(1));
      expect(errorEntries.first.message, contains('comm_timeout'));
      expect(errorEntries.first.message, contains('Communication timeout'));
      expect(errorEntries.first.category, LogCategory.libdc);

      await sub.cancel();
      testNotifier.dispose();
      await controller.close();
    });

    test(
      'Exception thrown by startDownload writes an ERROR log entry',
      () async {
        when(
          mockService.downloadEvents,
        ).thenAnswer((_) => const Stream.empty());
        when(
          mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
        ).thenThrow(StateError('boom'));

        final testNotifier = DownloadNotifier(
          service: mockService,
          repository: mockRepository,
        );

        final errorEntries = <LogEntry>[];
        final sub = LoggerService.logStream
            .where((e) => e.level == LogLevel.error)
            .listen(errorEntries.add);

        final device = DiscoveredDevice(
          id: 'test-err-2',
          name: 'Test Device',
          connectionType: DeviceConnectionType.usb,
          address: 'COM3',
          discoveredAt: DateTime(2026, 1, 1),
        );

        await testNotifier.startDownload(device);
        await Future<void>.delayed(Duration.zero);

        expect(errorEntries, hasLength(1));
        expect(errorEntries.first.message, contains('boom'));

        await sub.cancel();
        testNotifier.dispose();
      },
    );
  });
}
