import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_notifier_clock_sync_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;

  final device = DiscoveredDevice(
    id: 'device-1',
    name: 'Perdix',
    connectionType: DeviceConnectionType.ble,
    address: '00:11:22:33:44:55',
    discoveredAt: DateTime(2026, 1, 1),
  );

  final computer = DiveComputer(
    id: 'computer-1',
    name: 'My Perdix',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();
    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());
    when(
      mockService.startDownload(
        any,
        fingerprint: anyNamed('fingerprint'),
        syncClock: anyNamed('syncClock'),
      ),
    ).thenAnswer((_) async {});
  });

  bool capturedSyncClock() {
    return verify(
          mockService.startDownload(
            any,
            fingerprint: anyNamed('fingerprint'),
            syncClock: captureAnyNamed('syncClock'),
          ),
        ).captured.single
        as bool;
  }

  group('startDownload resolves the clock sync flag', () {
    test('asks the resolver with the saved computer id', () async {
      String? seenId;
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
        resolveClockSync: (id) {
          seenId = id;
          return true;
        },
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device, computer: computer);

      expect(seenId, 'computer-1');
      expect(capturedSyncClock(), isTrue);
    });

    test('asks with a null id for a device that is not saved yet', () async {
      String? seenId = 'unset';
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
        resolveClockSync: (id) {
          seenId = id;
          return false;
        },
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device);

      expect(seenId, isNull);
      expect(capturedSyncClock(), isFalse);
    });

    test('never syncs when no resolver is wired', () async {
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device, computer: computer);

      expect(capturedSyncClock(), isFalse);
    });
  });

  group('completion carries the clock sync status', () {
    late StreamController<DownloadEvent> controller;
    late DownloadNotifier notifier;

    setUp(() {
      controller = StreamController<DownloadEvent>.broadcast();
      addTearDown(controller.close);
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);
      notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(notifier.dispose);
    });

    test('parses the wire name into state', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0, clockSyncStatus: 'unsupported'));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.phase, DownloadPhase.complete);
      expect(notifier.state.clockSyncStatus, ClockSyncStatus.unsupported);
    });

    test('a completion without a status reads as not requested', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.clockSyncStatus, ClockSyncStatus.notRequested);
    });

    test('a new download clears the previous status', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0, clockSyncStatus: 'synced'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.clockSyncStatus, ClockSyncStatus.synced);

      await notifier.startDownload(device);

      expect(notifier.state.clockSyncStatus, isNull);
    });
  });

  test('DownloadState.copyWith keeps and clears the status', () {
    const initial = DownloadState();
    final synced = initial.copyWith(clockSyncStatus: ClockSyncStatus.synced);
    expect(synced.clockSyncStatus, ClockSyncStatus.synced);
    expect(
      synced.copyWith(phase: DownloadPhase.complete).clockSyncStatus,
      ClockSyncStatus.synced,
    );
    expect(synced.copyWith(clearClockSyncStatus: true).clockSyncStatus, isNull);
  });
}
