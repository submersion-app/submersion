import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

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

/// Records start() without timers or database writes.
class _SpyRecorder extends GpsTrackRecorder {
  _SpyRecorder() : super(repository: GpsTrackRepository());

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

Future<void> _pump(
  WidgetTester tester, {
  GpsTrackRecorder? recorder,
  Stream<GpsRecorderState>? state,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackRecorderProvider.overrideWithValue(recorder ?? _SpyRecorder()),
        if (state != null)
          gpsRecorderStateProvider.overrideWith((ref) => state),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GpsRecordCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final defaultGeolocator = GeolocatorPlatform.instance;
  tearDown(() => GeolocatorPlatform.instance = defaultGeolocator);

  test('only phones and tablets can record', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(canRecordGpsTracks, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(canRecordGpsTracks, isFalse);
  });

  testWidgets('idle shows the start button', (tester) async {
    await _pump(tester);
    expect(find.text('Start logging'), findsOneWidget);
  });

  testWidgets('recording shows points, last fix and stop', (tester) async {
    await _pump(
      tester,
      state: Stream.value(
        GpsRecorderState(
          status: GpsRecorderStatus.recording,
          trackId: 't1',
          pointCount: 4,
          startedAt: DateTime.now().toUtc(),
          lastFixAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 2),
          ),
          lastFixAccuracy: 8,
        ),
      ),
    );
    expect(find.text('Recording - 4 points'), findsOneWidget);
    expect(find.textContaining('Last fix'), findsOneWidget);
    expect(find.text('Stop logging'), findsOneWidget);
  });

  testWidgets('recording before the first fix says it is waiting', (
    tester,
  ) async {
    await _pump(
      tester,
      state: Stream.value(
        GpsRecorderState(
          status: GpsRecorderStatus.recording,
          trackId: 't1',
          pointCount: 0,
          startedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    expect(find.text('Waiting for GPS fix'), findsOneWidget);
  });

  testWidgets('warns when location services are disabled', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
    await _pump(tester);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(find.text('Location services are turned off.'), findsOneWidget);
  });

  testWidgets('warns when permission is denied', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.denied,
    );
    await _pump(tester);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Location permission is required to record a GPS track. '
        'Enable it in system settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('starts recording once permission is granted', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.whileInUse,
    );
    final recorder = _SpyRecorder();
    await _pump(tester, recorder: recorder);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(recorder.started, isTrue);
  });
}
