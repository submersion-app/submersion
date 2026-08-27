import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_logger_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

/// Fifty tracks, one per day, three fixes each.
List<GpsTrack> _fiftyTracks() => [
  for (var d = 0; d < 50; d++)
    GpsTrack(
      id: 'track-$d',
      startTime: DateTime.utc(
        2026,
        5,
        1,
      ).add(Duration(days: d)).millisecondsSinceEpoch,
      endTime: DateTime.utc(
        2026,
        5,
        1,
      ).add(Duration(days: d, hours: 4)).millisecondsSinceEpoch,
      pointCount: 3,
      points: [
        for (var i = 0; i < 3; i++)
          GpsTrackPoint(
            timestamp:
                DateTime.utc(
                  2026,
                  5,
                  1,
                ).add(Duration(days: d, minutes: i)).millisecondsSinceEpoch ~/
                1000,
            latitude: 20.0 + i * 0.001,
            longitude: -87.0 + i * 0.001,
          ),
      ],
    ),
];

Future<void> _pumpFifty(WidgetTester tester) async {
  final base = await getBaseOverrides();
  final tracks = _fiftyTracks();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith((ref) async => tracks),
        for (final track in tracks)
          gpsTrackGeometryProvider((
            track.id,
            TrackLod.thumbnail,
          )).overrideWith((ref) async => track.points),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GpsLoggerPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 50-track list builds only the visible thumbnails', (
    tester,
  ) async {
    await _pumpFifty(tester);

    // The guard that matters: if the list eagerly built every row, 50
    // FlutterMap instances would exist at once, each with its own controller,
    // camera, and tile manager. A handful on screen is fine.
    final built = find.byType(GpsTrackThumbnail).evaluate().length;
    expect(
      built,
      lessThan(15),
      reason: 'SliverList.builder must not build offscreen rows',
    );
    expect(built, greaterThan(0), reason: 'visible rows must render');
  });

  testWidgets('scrolling a 50-track list settles without exceptions', (
    tester,
  ) async {
    await _pumpFifty(tester);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -3000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
