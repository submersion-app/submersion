import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_cards.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The GPS track's card editors (issue #4527, plan 5).
void main() {
  final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
  final track = GpsTrack(
    id: 't1',
    startTime: startMs,
    endTime: startMs + 4 * 3600 * 1000,
    points: [
      for (var h = 0; h <= 4; h++)
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20,
          longitude: -87,
        ),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget editor) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(overrides: overrides, child: editor));
    await tester.pumpAndSettle();
  }

  testWidgets('the trim editor sets nothing until a drag ends', (tester) async {
    final session = EditSession(track);
    addTearDown(session.dispose);
    await pump(tester, GpsTrackTrimCardEditor(session: session));

    final slider = tester.getRect(find.byType(RangeSlider));
    final gesture = await tester.startGesture(
      Offset(slider.left + 24, slider.center.dy),
    );
    await gesture.moveBy(Offset(slider.width * 0.3, 0));
    await tester.pump();
    expect(session.changedCardIds, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(session.changedCardIds, {'trim'});
    expect(session.valueOf(gpsTrackTrimField).startMs, greaterThan(startMs));
  });

  testWidgets('Reset trim is off while there is no trim', (tester) async {
    final session = EditSession(track);
    addTearDown(session.dispose);
    await pump(tester, GpsTrackTrimCardEditor(session: session));

    final reset = tester.widget<TextButton>(
      find.byKey(const ValueKey('gps-track-reset-trim')),
    );
    expect(reset.onPressed, isNull);
  });

  testWidgets('the name editor writes through as the diver types', (
    tester,
  ) async {
    final session = EditSession(track);
    addTearDown(session.dispose);
    await pump(tester, GpsTrackHeaderCardEditor(session: session));

    await tester.enterText(find.byType(TextField), 'Reef');
    await tester.pump();

    expect(session.valueOf(gpsTrackNameField), 'Reef');
    expect(session.changedCardIds, {'header'});
  });

  testWidgets('dragging one handle leaves the other end open', (tester) async {
    final session = EditSession(track);
    addTearDown(session.dispose);
    await pump(tester, GpsTrackTrimCardEditor(session: session));

    final slider = tester.getRect(find.byType(RangeSlider));
    // The end handle, dragged in from the right.
    final gesture = await tester.startGesture(
      Offset(slider.right - 24, slider.center.dy),
    );
    await gesture.moveBy(Offset(-slider.width * 0.3, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final trim = session.valueOf(gpsTrackTrimField);
    expect(trim.startMs, isNull);
    expect(trim.endMs, lessThan(startMs + 4 * 3600 * 1000));
  });
}
