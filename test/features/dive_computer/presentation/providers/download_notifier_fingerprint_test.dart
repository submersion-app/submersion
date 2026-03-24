import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveImportService, DiveComputerService])
import 'download_notifier_fingerprint_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveImportService mockImportService;
  late MockDiveComputerService mockService;
  late DownloadNotifier notifier;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockImportService = MockDiveImportService();
    mockService = MockDiveComputerService();

    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());

    notifier = DownloadNotifier(
      service: mockService,
      importService: mockImportService,
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

  group('fingerprint persistence after import', () {
    test('updateLastFingerprint is called after successful import', () async {
      final computer = DiveComputer(
        id: 'comp-1',
        name: 'Test Computer',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final importedDives = [
        DownloadedDive(
          startTime: DateTime(2026, 3, 1, 10, 0),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'abc123',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 3, 2, 14, 0),
          durationSeconds: 2400,
          maxDepth: 25.0,
          profile: [],
          fingerprint: 'def456',
        ),
      ];

      when(
        mockImportService.importDives(
          dives: anyNamed('dives'),
          computer: anyNamed('computer'),
          mode: anyNamed('mode'),
          defaultResolution: anyNamed('defaultResolution'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => ImportResult.success(
          imported: 2,
          skipped: 0,
          updated: 0,
          importedDiveIds: ['d1', 'd2'],
          importedDives: importedDives,
        ),
      );

      when(
        mockRepository.incrementDiveCount(any, by: anyNamed('by')),
      ).thenAnswer((_) async {});
      when(mockRepository.updateLastDownload(any)).thenAnswer((_) async {});
      when(
        mockRepository.updateLastFingerprint(any, any),
      ).thenAnswer((_) async {});

      await notifier.importDives(computer: computer);

      // Verify newest fingerprint was persisted (def456 is from March 2)
      verify(
        mockRepository.updateLastFingerprint('comp-1', 'def456'),
      ).called(1);
    });

    test('updateLastFingerprint is NOT called when import fails', () async {
      final computer = DiveComputer(
        id: 'comp-1',
        name: 'Test Computer',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      when(
        mockImportService.importDives(
          dives: anyNamed('dives'),
          computer: anyNamed('computer'),
          mode: anyNamed('mode'),
          defaultResolution: anyNamed('defaultResolution'),
          diverId: anyNamed('diverId'),
        ),
      ).thenThrow(Exception('Database error'));

      await notifier.importDives(computer: computer);

      verifyNever(mockRepository.updateLastFingerprint(any, any));
    });

    test(
      'updateLastFingerprint is NOT called when no dives have fingerprints',
      () async {
        final computer = DiveComputer(
          id: 'comp-1',
          name: 'Test Computer',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        when(
          mockImportService.importDives(
            dives: anyNamed('dives'),
            computer: anyNamed('computer'),
            mode: anyNamed('mode'),
            defaultResolution: anyNamed('defaultResolution'),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer(
          (_) async => ImportResult.success(
            imported: 1,
            skipped: 0,
            updated: 0,
            importedDiveIds: ['d1'],
            importedDives: [
              DownloadedDive(
                startTime: DateTime(2026, 3, 1),
                durationSeconds: 3600,
                maxDepth: 20.0,
                profile: [],
                // no fingerprint
              ),
            ],
          ),
        );

        when(
          mockRepository.incrementDiveCount(any, by: anyNamed('by')),
        ).thenAnswer((_) async {});
        when(mockRepository.updateLastDownload(any)).thenAnswer((_) async {});

        await notifier.importDives(computer: computer);

        verifyNever(mockRepository.updateLastFingerprint(any, any));
      },
    );
  });

  group('error event sets errorCode', () {
    test('DownloadErrorEvent populates errorCode in state', () async {
      final controller = StreamController<DownloadEvent>.broadcast();
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);

      final testNotifier = DownloadNotifier(
        service: mockService,
        importService: mockImportService,
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
