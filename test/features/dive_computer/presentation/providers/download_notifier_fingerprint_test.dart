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
import 'package:submersion/features/dive_computer/domain/services/first_sync_cutoff.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

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

  group('sinceCutoff fingerprint synthesis', () {
    final shearwaterDevice = DiscoveredDevice(
      id: 'shearwater-1',
      name: 'Teric',
      connectionType: DeviceConnectionType.ble,
      address: '00:11:22:33:44:55',
      discoveredAt: DateTime(2026, 1, 1),
      recognizedModel: const DeviceModel(
        id: 'shearwater_teric',
        manufacturer: 'Shearwater',
        model: 'Teric',
        connectionTypes: [DeviceConnectionType.ble],
      ),
    );

    final suuntoDevice = DiscoveredDevice(
      id: 'suunto-1',
      name: 'D5',
      connectionType: DeviceConnectionType.ble,
      address: '00:11:22:33:44:66',
      discoveredAt: DateTime(2026, 1, 1),
      recognizedModel: const DeviceModel(
        id: 'suunto_d5',
        manufacturer: 'Suunto',
        model: 'D5',
        connectionTypes: [DeviceConnectionType.ble],
      ),
    );

    final computerWithoutFp = DiveComputer(
      id: 'computer-1',
      name: 'My Teric',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final computerWithFp = DiveComputer(
      id: 'computer-2',
      name: 'My Teric',
      lastDiveFingerprint: 'stored-fingerprint',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      when(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).thenAnswer((_) async {});
    });

    test('synthesizes fingerprint from cutoff for Shearwater with no stored '
        'fingerprint', () async {
      final cutoff = DateTime.utc(2026, 6, 12, 14, 30, 5);
      notifier.setSinceCutoff(cutoff);
      await notifier.startDownload(
        shearwaterDevice,
        computer: computerWithoutFp,
      );

      final captured =
          verify(
                mockService.startDownload(
                  any,
                  fingerprint: captureAnyNamed('fingerprint'),
                ),
              ).captured.single
              as String?;

      expect(captured, synthesizeShearwaterFingerprint(cutoff));
    });

    test('stored fingerprint wins over cutoff', () async {
      notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
      await notifier.startDownload(shearwaterDevice, computer: computerWithFp);

      final captured =
          verify(
                mockService.startDownload(
                  any,
                  fingerprint: captureAnyNamed('fingerprint'),
                ),
              ).captured.single
              as String?;

      expect(captured, 'stored-fingerprint');
    });

    test('no synthesis for non-Shearwater device', () async {
      notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
      await notifier.startDownload(suuntoDevice, computer: computerWithoutFp);

      final captured =
          verify(
                mockService.startDownload(
                  any,
                  fingerprint: captureAnyNamed('fingerprint'),
                ),
              ).captured.single
              as String?;

      expect(captured, isNull);
    });

    test('no synthesis when newDivesOnly is off', () async {
      notifier.setNewDivesOnly(false);
      notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
      await notifier.startDownload(
        shearwaterDevice,
        computer: computerWithoutFp,
      );

      final captured =
          verify(
                mockService.startDownload(
                  any,
                  fingerprint: captureAnyNamed('fingerprint'),
                ),
              ).captured.single
              as String?;

      expect(captured, isNull);
    });

    test('reset clears sinceCutoff', () {
      notifier.setSinceCutoff(DateTime.utc(2026, 6, 12));
      notifier.reset();
      expect(notifier.state.sinceCutoff, isNull);
    });

    test('sinceCutoff defaults to null', () {
      expect(notifier.state.sinceCutoff, isNull);
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
    List<LogEntry> captureLibdcErrors() {
      final entries = <LogEntry>[];
      final sub = LoggerService.logStream
          .where(
            (e) => e.level == LogLevel.error && e.category == LogCategory.libdc,
          )
          .listen(entries.add);
      addTearDown(sub.cancel);
      return entries;
    }

    test('DownloadErrorEvent writes an ERROR log entry', () async {
      final controller = StreamController<DownloadEvent>.broadcast();
      addTearDown(controller.close);
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);
      when(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).thenAnswer((_) async {});

      final testNotifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(testNotifier.dispose);

      final errorEntries = captureLibdcErrors();

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
        addTearDown(testNotifier.dispose);

        final errorEntries = captureLibdcErrors();

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
      },
    );

    test('startDownload catch block cancels the events subscription', () async {
      final controller = StreamController<DownloadEvent>.broadcast();
      addTearDown(controller.close);
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);
      when(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).thenThrow(StateError('boom'));

      final testNotifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(testNotifier.dispose);

      final errorEntries = captureLibdcErrors();

      final device = DiscoveredDevice(
        id: 'test-err-3',
        name: 'Test Device',
        connectionType: DeviceConnectionType.usb,
        address: 'COM3',
        discoveredAt: DateTime(2026, 1, 1),
      );

      await testNotifier.startDownload(device);

      // If the catch block did not cancel the subscription, this stray
      // event would reach _onDownloadEvent and emit a second error log.
      controller.add(
        DownloadErrorEvent(
          DiveComputerError(code: 'stray', message: 'Stray event'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(errorEntries, hasLength(1));
      expect(errorEntries.first.message, contains('boom'));
    });
  });
}
