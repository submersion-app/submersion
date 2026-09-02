import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';

import 'download_notifier_fingerprint_test.mocks.dart';

/// Issue #1092: a live download has to read the diver's surfacing-pressure
/// preference at the moment each dive arrives, so the reading it stores is not
/// the one the computer logged minutes after the diver was back on the boat.
void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;
  late StreamController<pigeon.DownloadEvent> events;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();
    events = StreamController<pigeon.DownloadEvent>.broadcast();
    when(mockService.downloadEvents).thenAnswer((_) => events.stream);
    when(
      mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => events.close());

  final device = DiscoveredDevice(
    id: 'shearwater-1',
    name: 'Petrel 3',
    connectionType: DeviceConnectionType.ble,
    address: '00:11:22:33:44:55',
    discoveredAt: DateTime(2026, 1, 1),
  );

  /// The dive from the issue report: 41 bar of oxygen left at 1.2 m, bled to
  /// 4 bar by the time the recording stops on the surface.
  pigeon.ParsedDive bleedingOxygenDive() => pigeon.ParsedDive(
    fingerprint: 'fp-1',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 51.0,
    avgDepthMeters: 30.0,
    durationSeconds: 4140,
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0)],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: 0,
        startPressureBar: 200.0,
        endPressureBar: 4.0,
      ),
    ],
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 3970,
        depthMeters: 1.2,
        pressureBar: 41.0,
        tankIndex: 0,
      ),
      pigeon.ProfileSample(
        timeSeconds: 4140,
        depthMeters: 0.0,
        pressureBar: 4.0,
        tankIndex: 0,
      ),
    ],
    events: const [],
  );

  Future<double?> downloadedEndPressure({required bool trim}) async {
    final notifier = DownloadNotifier(
      service: mockService,
      repository: mockRepository,
      trimTankPressureAtSurfacing: () => trim,
    );
    addTearDown(notifier.dispose);

    await notifier.startDownload(device);
    events.add(pigeon.DiveDownloadedEvent(bleedingOxygenDive()));
    await Future<void>.delayed(Duration.zero);

    return notifier.state.downloadedDives.single.tanks.single.endPressure;
  }

  test(
    'stores the end pressure at surfacing when the diver opted in',
    () async {
      expect(await downloadedEndPressure(trim: true), 41.0);
    },
  );

  test('stores the computer end pressure when the diver opted out', () async {
    expect(await downloadedEndPressure(trim: false), 4.0);
  });
}
