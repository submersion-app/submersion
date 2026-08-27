import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: t,
  latitude: 20.0 + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

final _points = [p(0), p(10), p(20), p(30)];

GpsTrack _track() => GpsTrack(
  id: 'track-1',
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: _points.length,
  points: _points,
);

Dive _dive(String id) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 5, 22, 9),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(20.001, -87.001),
);

Future<void> _pump(WidgetTester tester, {required List<Dive> dives}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackDetailProvider('track-1').overrideWith((ref) async => _track()),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => _points),
        divesOnTrackProvider('track-1').overrideWith((ref) async => dives),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GpsTrackDetailPage(trackId: 'track-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders start and end markers', (tester) async {
    await _pump(tester, dives: const []);
    expect(find.byKey(const ValueKey('track-start-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-end-marker')), findsOneWidget);
  });

  testWidgets('renders one marker per dive on the track', (tester) async {
    await _pump(tester, dives: [_dive('dive-1'), _dive('dive-2')]);
    expect(
      find.byKey(const ValueKey('track-dive-marker-dive-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('track-dive-marker-dive-2')),
      findsOneWidget,
    );
  });

  testWidgets('renders no dive markers when the track has none', (
    tester,
  ) async {
    await _pump(tester, dives: const []);
    expect(
      find.byWidgetPredicate(
        (w) => w.key.toString().contains('track-dive-marker'),
      ),
      findsNothing,
    );
  });

  testWidgets('skips a dive with no entry location', (tester) async {
    final noGps = Dive(
      id: 'dive-3',
      diveNumber: 3,
      dateTime: DateTime.utc(2026, 5, 22, 9),
      maxDepth: 30.0,
    );
    await _pump(tester, dives: [noGps]);
    expect(
      find.byKey(const ValueKey('track-dive-marker-dive-3')),
      findsNothing,
    );
  });
}
