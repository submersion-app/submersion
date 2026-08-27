import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: 20.0 + t * 0.001, longitude: -87.0);

final _points = [p(0), p(1), p(2), p(3)];

GpsTrack _track() => GpsTrack(
  id: 'track-1',
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: _points.length,
  points: _points,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides],
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
  testWidgets('renders a map with the track drawn', (tester) async {
    await _pump(
      tester,
      overrides: [
        gpsTrackDetailProvider('track-1').overrideWith((ref) async => _track()),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => _points),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer<int>), findsOneWidget);
  });

  testWidgets('shows a not-found message for a missing track', (tester) async {
    await _pump(
      tester,
      overrides: [
        gpsTrackDetailProvider('track-1').overrideWith((ref) async => null),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => const <GpsTrackPoint>[]),
      ],
    );

    expect(find.text('This track is no longer available.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('shows an unreadable message when decoding throws', (
    tester,
  ) async {
    await _pump(
      tester,
      overrides: [
        gpsTrackDetailProvider(
          'track-1',
        ).overrideWith((ref) async => throw const FormatException('bad gzip')),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => const <GpsTrackPoint>[]),
      ],
    );

    expect(find.text('Track data could not be read.'), findsOneWidget);
  });

  testWidgets('shows an empty message for a track with no fixes', (
    tester,
  ) async {
    await _pump(
      tester,
      overrides: [
        gpsTrackDetailProvider('track-1').overrideWith(
          (ref) async => const GpsTrack(
            id: 'track-1',
            startTime: 1700000000000,
            endTime: 1700003600000,
          ),
        ),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => const <GpsTrackPoint>[]),
      ],
    );

    expect(find.text('This track has no recorded positions.'), findsOneWidget);
  });
}
