import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: t,
  latitude: 20.0 + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

final _points = [p(0), p(10), p(20), p(30), p(40)];

GpsTrack _track() => GpsTrack(
  id: 'track-1',
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: _points.length,
  points: _points,
);

Future<int> _pumpCountingReads(
  WidgetTester tester,
  void Function(int) onRead,
) async {
  var reads = 0;
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackDetailProvider('track-1').overrideWith((ref) async => _track()),
        gpsTrackGeometryProvider(('track-1', TrackLod.detail)).overrideWith((
          ref,
        ) async {
          reads++;
          onRead(reads);
          return _points;
        }),
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
  return reads;
}

void main() {
  testWidgets('toggling to Speed re-buckets without re-reading geometry', (
    tester,
  ) async {
    var reads = 0;
    await _pumpCountingReads(tester, (n) => reads = n);
    expect(reads, 1);

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    // The whole point of the run-bucketing design: changing colour mode
    // re-runs bucketize only. No second decode, no second simplify.
    expect(reads, 1);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
    // Speed mode draws a legend.
    expect(find.text('Slower'), findsNothing);
  });

  testWidgets('defaults to plain mode with no legend', (tester) async {
    await _pumpCountingReads(tester, (_) {});
    expect(find.text('Start'), findsNothing);
    expect(find.text('Slower'), findsNothing);
  });

  testWidgets('switching to Time shows the elapsed legend', (tester) async {
    await _pumpCountingReads(tester, (_) {});
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
  });

  testWidgets('a mode toggle does not rebuild the stats header', (
    tester,
  ) async {
    // The page used to watch trackColorModeProvider in its own build, so a
    // toggle rebuilt the whole Scaffold body - and TrackStatsHeader
    // recomputes distance and speedRange over the full decoded list, up to
    // ~20k points, on every rebuild. Scoping the watch to the selector keeps
    // the toggle to the frame it is supposed to cost.
    await _pumpCountingReads(tester, (_) {});

    final before = tester.element(find.byType(TrackStatsHeader));
    final beforeWidget = tester.widget<TrackStatsHeader>(
      find.byType(TrackStatsHeader),
    );

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    // Same Element and the very same Widget instance: Flutter never asked
    // the header to build again.
    expect(tester.element(find.byType(TrackStatsHeader)), same(before));
    expect(
      tester.widget<TrackStatsHeader>(find.byType(TrackStatsHeader)),
      same(beforeWidget),
    );
  });
}
