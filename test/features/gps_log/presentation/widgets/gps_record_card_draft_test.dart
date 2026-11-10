import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';

import 'dive_mark_buttons_test.dart';

class _Geolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
}

/// Records start() and stop() without timers or database writes.
class _SpyRecorder extends GpsTrackRecorder {
  _SpyRecorder(this.log) : super(repository: GpsTrackRepository());

  final List<String> log;

  @override
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async => log.add('start');

  @override
  Future<void> stop() async => log.add('stop');
}

/// The card's Stop and idle "Entered water" around a draft (issue #637).
void main() {
  final defaultGeolocator = GeolocatorPlatform.instance;
  setUp(() => GeolocatorPlatform.instance = _Geolocator());
  tearDown(() => GeolocatorPlatform.instance = defaultGeolocator);

  Future<({List<String> recorder, FakeDiveMarks marks})> pump(
    WidgetTester tester, {
    required bool recording,
    Dive? open,
    bool marksFail = false,
  }) async {
    final log = <String>[];
    final marks = FakeDiveMarks()..fail = marksFail;
    await pumpMarks(
      tester,
      harness([
        ...await markOverrides(marks, open: open),
        gpsTrackRecorderProvider.overrideWithValue(_SpyRecorder(log)),
        if (recording)
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(
              const GpsRecorderState(
                status: GpsRecorderStatus.recording,
                trackId: 't1',
                pointCount: 2,
              ),
            ),
          ),
      ], const GpsRecordCard()),
    );
    return (recorder: log, marks: marks);
  }

  testWidgets('stopping with a draft open asks, and Surface now closes it '
      'first', (tester) async {
    final log = await pump(tester, recording: true, open: openDraft);

    await tester.tap(find.text('Stop logging'));
    await tester.pumpAndSettle();
    expect(find.text('Still in the water?'), findsOneWidget);

    await tester.tap(find.text('Surface now'));
    await tester.pumpAndSettle();
    expect(log.marks.calls, ['surfaced']);
    expect(log.recorder, ['stop']);
  });

  testWidgets('a Surface now that fails still stops the recording, and the '
      'error is logged, never left unhandled', (tester) async {
    final log = await pump(
      tester,
      recording: true,
      open: openDraft,
      marksFail: true,
    );

    await tester.tap(find.text('Stop logging'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surface now'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(log.recorder, ['stop']);
  });

  testWidgets('Leave open stops without closing the draft', (tester) async {
    final log = await pump(tester, recording: true, open: openDraft);

    await tester.tap(find.text('Stop logging'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave open'));
    await tester.pumpAndSettle();

    expect(log.marks.calls, isEmpty);
    expect(log.recorder, ['stop']);
  });

  testWidgets('Cancel keeps recording', (tester) async {
    final log = await pump(tester, recording: true, open: openDraft);

    await tester.tap(find.text('Stop logging'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(log.recorder, isEmpty);
  });

  testWidgets('stopping with no draft open does not ask', (tester) async {
    final log = await pump(tester, recording: true);

    await tester.tap(find.text('Stop logging'));
    await tester.pumpAndSettle();

    expect(find.text('Still in the water?'), findsNothing);
    expect(log.recorder, ['stop']);
  });

  testWidgets('an Entered water that fails while idle is logged, never '
      'left unhandled', (tester) async {
    final log = await pump(tester, recording: false, marksFail: true);

    await tester.tap(find.text('Entered water'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(log.recorder, ['start']);
  });

  testWidgets('Entered water while idle starts the recording first', (
    tester,
  ) async {
    final log = await pump(tester, recording: false);

    await tester.tap(find.text('Entered water'));
    await tester.pumpAndSettle();

    expect(log.recorder, ['start']);
    expect(log.marks.calls, ['entered:a']);
  });
}
