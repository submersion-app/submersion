import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
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

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> app({GpsTrackRecorder? recorder}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (recorder != null)
          gpsTrackRecorderProvider.overrideWithValue(recorder),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GpsLoggerPage(),
      ),
    );
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

  testWidgets('completed tracks render as tiles with delete affordance', (
    tester,
  ) async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await repo.finalizeTrack(id, endTimeMs: 1700005400000);

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('No GPS tracks recorded yet'), findsNothing);
    expect(find.byIcon(Icons.route_outlined), findsOneWidget);
    // 1 point, 90 minutes.
    expect(find.text('1 point, 1 h 30 min'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
