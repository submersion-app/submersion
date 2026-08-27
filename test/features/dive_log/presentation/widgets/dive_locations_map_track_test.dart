import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: t,
  latitude: 12.345 + t * 0.0001,
  longitude: 98.765 + t * 0.0001,
);

final _runs = [
  TrackRun(points: [p(0), p(1), p(2), p(3)], bucket: 0),
];

Future<void> _pump(
  WidgetTester tester, {
  List<TrackRun>? trackRuns,
  bool fitToTrack = false,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        // MapCompassButton reads AppLocalizations for its tooltip.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveLocationsMap(
            entry: const GeoPoint(12.345, 98.765),
            exit: const GeoPoint(12.346, 98.766),
            interactive: true,
            trackRuns: trackRuns,
            fitToTrack: fitToTrack,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws no track layer when trackRuns is null', (tester) async {
    await _pump(tester);
    expect(find.byType(PolylineLayer<int>), findsNothing);
  });

  testWidgets('draws the track when runs are supplied', (tester) async {
    await _pump(tester, trackRuns: _runs);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('still renders the entry and exit markers with a track', (
    tester,
  ) async {
    await _pump(tester, trackRuns: _runs);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
  });

  testWidgets('keeps the entry-exit drift line alongside the track', (
    tester,
  ) async {
    await _pump(tester, trackRuns: _runs);
    // The untyped PolylineLayer is the dotted drift line; the typed one is
    // the track. Both must survive.
    expect(find.byType(PolylineLayer<Object>), findsOneWidget);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('handles an empty run list without throwing', (tester) async {
    await _pump(tester, trackRuns: const []);
    expect(tester.takeException(), isNull);
    expect(find.byType(PolylineLayer<int>), findsNothing);
  });

  testWidgets('renders without throwing when fitting to the track', (
    tester,
  ) async {
    await _pump(tester, trackRuns: _runs, fitToTrack: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
