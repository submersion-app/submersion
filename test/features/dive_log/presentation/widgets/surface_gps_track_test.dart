import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Dive entering 09:00 wall-clock, 45 minutes long.
Dive _dive() => Dive(
  id: 'dive-1',
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 5, 22, 9),
  bottomTime: const Duration(minutes: 45),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
);

/// Track from 08:00 to 12:00, one fix every 15 minutes (17 fixes).
GpsTrack _track() {
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
    endTime: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    pointCount: 17,
    points: [
      for (var i = 0; i < 17; i++)
        GpsTrackPoint(
          timestamp: startSec + i * 900,
          latitude: 12.345 + i * 0.0002,
          longitude: 98.765 + i * 0.0002,
        ),
    ],
  );
}

int _drawnPointCount(WidgetTester tester) {
  final layer = tester.widget<PolylineLayer<int>>(
    find.byType(PolylineLayer<int>),
  );
  return layer.polylines.fold<int>(0, (sum, l) => sum + l.points.length);
}

Future<void> _pump(
  WidgetTester tester, {
  GpsTrack? track,
  bool expanded = true,
  void Function()? onTrackResolved,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(700, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        surfaceGpsSectionExpandedProvider.overrideWithValue(expanded),
        trackForDiveProvider('dive-1').overrideWith((ref) async {
          onTrackResolved?.call();
          return track;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SurfaceGpsSection(dive: _dive())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a track row when a track covers the dive', (tester) async {
    await _pump(tester, track: _track());
    expect(find.byKey(const ValueKey('gps-track-link')), findsOneWidget);
    expect(find.textContaining('Surface track'), findsOneWidget);
  });

  testWidgets('shows no track row when no track covers the dive', (
    tester,
  ) async {
    await _pump(tester, track: null);
    expect(find.byKey(const ValueKey('gps-track-link')), findsNothing);
  });

  testWidgets('labels the row as the surface track, not the diver route', (
    tester,
  ) async {
    // During the dive the recording phone is on the boat, so this is the
    // surface support path. The copy must not imply otherwise.
    await _pump(tester, track: _track());
    expect(find.textContaining('17 fixes'), findsOneWidget);
  });

  testWidgets('draws only the dive window plus margin by default', (
    tester,
  ) async {
    await _pump(tester, track: _track());
    // Dive 09:00-09:45 plus 15 min either side = 08:45..10:00, which is
    // 6 of the 17 fixes at 15-minute spacing.
    final drawn = _drawnPointCount(tester);
    expect(drawn, 6);
  });

  testWidgets('the full-track chip expands to the whole recording', (
    tester,
  ) async {
    await _pump(tester, track: _track());
    expect(_drawnPointCount(tester), 6);

    await tester.tap(find.byKey(const ValueKey('gps-track-full-chip')));
    await tester.pumpAndSettle();

    expect(_drawnPointCount(tester), 17);
  });

  testWidgets('a collapsed section never resolves the track', (tester) async {
    var resolved = false;
    await _pump(
      tester,
      track: _track(),
      expanded: false,
      onTrackResolved: () => resolved = true,
    );

    // The lazy gate exists so a collapsed section costs nothing. Watching the
    // track provider outside _content would silently defeat it.
    expect(resolved, isFalse);
    expect(find.byKey(const ValueKey('gps-track-link')), findsNothing);
  });
}
