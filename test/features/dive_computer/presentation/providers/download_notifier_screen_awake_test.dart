import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/screen_awake.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';

import 'download_notifier_fingerprint_test.mocks.dart';

/// Issue #1646: a dive-computer download runs while the user watches a
/// progress bar, and their phone locks itself and suspends the BLE transfer
/// mid-dive. The notifier holds the screen awake for exactly the length of a
/// download.
void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;
  late StreamController<DownloadEvent> events;
  late List<bool> toggles;
  DownloadNotifier? notifier;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();
    events = StreamController<DownloadEvent>.broadcast();
    when(mockService.downloadEvents).thenAnswer((_) => events.stream);
    when(
      mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});
    when(mockService.cancelDownload()).thenAnswer((_) async {});

    toggles = [];
    ScreenAwake.debugToggle = ({required bool enable}) async {
      toggles.add(enable);
    };
  });

  tearDown(() async {
    // Dispose the notifier before debugReset so the seam that took the hold
    // is still in place to release it; debugReset then only clears the seam.
    notifier?.dispose();
    notifier = null;
    await events.close();
    ScreenAwake.debugReset();
  });

  final device = DiscoveredDevice(
    id: 'nautic-1',
    name: 'Suunto Nautic 2604C3003306',
    connectionType: DeviceConnectionType.ble,
    address: '00:11:22:33:44:55',
    discoveredAt: DateTime(2026, 1, 1),
  );

  DownloadNotifier makeNotifier() {
    notifier = DownloadNotifier(
      service: mockService,
      repository: mockRepository,
    );
    return notifier!;
  }

  test('takes the lock when a download starts', () async {
    final notifier = makeNotifier();
    await notifier.startDownload(device);

    expect(toggles, [true]);
    expect(ScreenAwake.debugHolders, 1);
  });

  test('releases the lock when the download completes', () async {
    final notifier = makeNotifier();
    await notifier.startDownload(device);

    events.add(
      DownloadCompleteEvent(2, serialNumber: null, firmwareVersion: null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(toggles, [true, false]);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('releases the lock when the download errors', () async {
    final notifier = makeNotifier();
    await notifier.startDownload(device);

    events.add(
      DownloadErrorEvent(
        DiveComputerError(code: 'timeout', message: 'No response'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(toggles, [true, false]);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('releases the lock when the download is cancelled', () async {
    final notifier = makeNotifier();
    await notifier.startDownload(device);

    await notifier.cancelDownload();

    expect(toggles, [true, false]);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('holds the lock until the platform cancel call completes', () async {
    final cancelDone = Completer<void>();
    when(mockService.cancelDownload()).thenAnswer((_) => cancelDone.future);

    final notifier = makeNotifier();
    await notifier.startDownload(device);

    final cancelling = notifier.cancelDownload();
    await Future<void>.delayed(Duration.zero);
    expect(
      ScreenAwake.debugHolders,
      1,
      reason: 'the UI is still on the download screen during the round trip',
    );

    cancelDone.complete();
    await cancelling;
    expect(ScreenAwake.debugHolders, 0);
  });

  test('releases the lock even if the platform cancel throws', () async {
    when(mockService.cancelDownload()).thenThrow(StateError('boom'));

    final notifier = makeNotifier();
    await notifier.startDownload(device);

    await expectLater(notifier.cancelDownload(), throwsStateError);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('holds the lock through a PIN prompt', () async {
    final notifier = makeNotifier();
    await notifier.startDownload(device);

    events.add(PinCodeRequestEvent(device.address));
    await Future<void>.delayed(Duration.zero);

    expect(
      toggles,
      [true],
      reason: 'the user is reading a code off the watch; the transfer resumes',
    );
    expect(ScreenAwake.debugHolders, 1);
  });

  test('a retry does not stack a second lock', () async {
    final notifier = makeNotifier();

    await notifier.startDownload(device);
    events.add(
      DownloadErrorEvent(
        DiveComputerError(code: 'timeout', message: 'No response'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(toggles, [true, false]);

    // The retry path in DownloadStepWidget re-runs reset() then startDownload().
    notifier.reset();
    await notifier.startDownload(device);
    events.add(
      DownloadCompleteEvent(1, serialNumber: null, firmwareVersion: null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(toggles, [
      true,
      false,
      true,
      false,
    ], reason: 'each attempt takes and drops exactly one lock');
    expect(ScreenAwake.debugHolders, 0);
  });

  test('releases the lock if the notifier is disposed mid-download', () async {
    final notifier = DownloadNotifier(
      service: mockService,
      repository: mockRepository,
    );
    await notifier.startDownload(device);
    expect(toggles, [true]);

    notifier.dispose();

    expect(toggles, [true, false]);
    expect(ScreenAwake.debugHolders, 0);
  });
}
