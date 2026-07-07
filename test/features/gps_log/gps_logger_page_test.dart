import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_logger_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_database.dart';

Position _fix({required double lat, required double lon}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now().toUtc(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Swappable geolocator backend so the page's _startLogging branches
/// (location off / permission denied / granted) are reachable in tests.
class _FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestResult = LocationPermission.whileInUse,
  });

  final bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission requestResult;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = requestResult;
    return requestResult;
  }
}

/// Records whether start() was called without spinning up real timers or
/// DB writes, so the permission-granted path is testable without the
/// fake-zone/real-zone deadlock a live recorder would introduce.
class _SpyRecorder extends GpsTrackRecorder {
  _SpyRecorder(GpsTrackRepository repo) : super(repository: repo);

  bool started = false;

  @override
  bool get isRecording => started;

  @override
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    started = true;
  }
}

/// A match service whose sweep returns a fixed result or throws, so the
/// page's success/empty/error branches are all reachable without a DB.
class _FakeMatchService extends GpsTrackMatchService {
  _FakeMatchService({this.result = const [], this.fail = false})
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );

  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    if (fail) throw StateError('sweep failed');
    return result;
  }
}

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> app({
    GpsTrackRecorder? recorder,
    GpsTrackMatchService? matchService,
    Stream<GpsRecorderState>? recorderState,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/gps-log',
      routes: [
        GoRoute(
          path: '/gps-log',
          builder: (context, state) => const GpsLoggerPage(),
        ),
        GoRoute(
          path: '/dives/match-sites',
          builder: (context, state) =>
              const Scaffold(body: Text('MATCH-SITES-PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (recorder != null)
          gpsTrackRecorderProvider.overrideWithValue(recorder),
        if (matchService != null)
          gpsTrackMatchServiceProvider.overrideWithValue(matchService),
        if (recorderState != null)
          gpsRecorderStateProvider.overrideWith((ref) => recorderState),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<String> seedCompletedTrack() async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await repo.finalizeTrack(id, endTimeMs: 1700005400000);
    return id;
  }

  testWidgets(
    'desktop hides record controls, shows empty state',
    (tester) async {
      await tester.pumpWidget(await app());
      await tester.pumpAndSettle();
      expect(find.text('Start logging'), findsNothing);
      expect(find.text('No GPS tracks recorded yet'), findsOneWidget);
      expect(find.text('Match dives to GPS logs'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'mobile idle state shows the start button',
    (tester) async {
      await tester.pumpWidget(await app());
      await tester.pumpAndSettle();
      expect(find.text('Start logging'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'recording state shows point count and stop button',
    (tester) async {
      // Construct and drive the recorder entirely inside runAsync blocks:
      // futures capture their creation zone (including the record queue's
      // seed future made in the constructor), so anything created in the
      // fake zone can never complete or be awaited on the real event loop.
      late StreamController<Position> controller;
      late GpsTrackRecorder recorder;
      await tester.runAsync(() async {
        controller = StreamController<Position>();
        recorder = GpsTrackRecorder(
          repository: repo,
          positionStreamFactory: (_) => controller.stream,
        );
        await recorder.start(notificationTitle: 't', notificationText: 'x');
        controller.add(_fix(lat: 10, lon: 20));
        controller.add(_fix(lat: 10.001, lon: 20.001));
        // Let the stream deliver and the buffered writes land.
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (recorder.state.pointCount < 2 &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(await app(recorder: recorder));
      await tester.pumpAndSettle();
      expect(find.text('Recording - 2 points'), findsOneWidget);
      expect(find.text('Stop logging'), findsOneWidget);
      expect(find.text('Start logging'), findsNothing);

      // Stop inside the test body so no timers outlive the test.
      await tester.runAsync(() => recorder.stop());
      await tester.runAsync(() => controller.close());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'recording card shows last-fix age and accuracy',
    (tester) async {
      final state = GpsRecorderState(
        status: GpsRecorderStatus.recording,
        trackId: 't1',
        pointCount: 4,
        startedAt: DateTime.now().toUtc(),
        lastFixAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
        lastFixAccuracy: 8,
      );
      await tester.pumpWidget(await app(recorderState: Stream.value(state)));
      await tester.pumpAndSettle();
      expect(find.text('Recording - 4 points'), findsOneWidget);
      expect(find.textContaining('Last fix'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('completed tracks render as tiles with delete affordance', (
    tester,
  ) async {
    await seedCompletedTrack();

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('No GPS tracks recorded yet'), findsNothing);
    expect(find.byIcon(Icons.route_outlined), findsOneWidget);
    // 1 point, 90 minutes, compact app-wide duration style.
    expect(find.text('1 point, 1h 30m'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('match action reports positioned dives and links to review', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app(matchService: _FakeMatchService(result: const ['d1', 'd2'])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(find.text('2 dives positioned'), findsOneWidget);

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES-PAGE'), findsOneWidget);
  });

  testWidgets('match action reports when nothing matched', (tester) async {
    await tester.pumpWidget(await app(matchService: _FakeMatchService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(find.text('No dives matched a recorded track'), findsOneWidget);
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('match action surfaces an error snackbar on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app(matchService: _FakeMatchService(fail: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a track confirms then removes it', (tester) async {
    final id = await seedCompletedTrack();

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete track?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await repo.getTrack(id), isNull);
    expect(find.text('No GPS tracks recorded yet'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the track', (tester) async {
    final id = await seedCompletedTrack();

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.getTrack(id), isNotNull);
  });

  group('start logging', () {
    final defaultGeolocator = GeolocatorPlatform.instance;
    tearDown(() => GeolocatorPlatform.instance = defaultGeolocator);

    testWidgets(
      'warns when location services are disabled',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
        await tester.pumpWidget(await app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start logging'));
        await tester.pumpAndSettle();
        expect(find.text('Location services are turned off.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'warns when permission is denied',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocator(
          permission: LocationPermission.denied,
          requestResult: LocationPermission.denied,
        );
        await tester.pumpWidget(await app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start logging'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Location permission is required to record a GPS track. '
            'Enable it in system settings.',
          ),
          findsOneWidget,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'starts recording once permission is granted',
      (tester) async {
        GeolocatorPlatform.instance = _FakeGeolocator(
          permission: LocationPermission.denied,
          requestResult: LocationPermission.whileInUse,
        );
        final recorder = _SpyRecorder(repo);
        await tester.pumpWidget(await app(recorder: recorder));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start logging'));
        await tester.pumpAndSettle();
        expect(recorder.started, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  testWidgets('an interrupted recording surfaces a recovery notice', (
    tester,
  ) async {
    // Seed an orphan: started with buffered points but never finalized.
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(
      find.text('A previous recording was interrupted. The track was saved.'),
      findsOneWidget,
    );
    // The recovered track now renders as a completed tile.
    expect(find.byIcon(Icons.route_outlined), findsOneWidget);
  });
}
