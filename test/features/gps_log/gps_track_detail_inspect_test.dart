import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_point_info_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

/// A tight cluster so the drawn line crosses the middle of the viewport.
GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: 1700000000 + t,
  latitude: 20.0 + t * 0.0005,
  longitude: -87.0 + t * 0.0005,
  accuracy: 5.0,
);

final _points = [p(0), p(1), p(2), p(3), p(4), p(5), p(6), p(7), p(8)];

GpsTrack _track() => GpsTrack(
  id: 'track-1',
  startTime: 1700000000000,
  endTime: 1700000008000,
  pointCount: _points.length,
  points: _points,
);

Future<void> _pump(WidgetTester tester) async {
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
        divesOnTrackProvider('track-1').overrideWith((ref) async => const []),
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

/// Pumps with a heavily decimated geometry provider - only the endpoints -
/// while the hydrated track still carries every fix.
Future<void> _pumpDecimated(WidgetTester tester) async {
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
        )).overrideWith((ref) async => [_points.first, _points.last]),
        divesOnTrackProvider('track-1').overrideWith((ref) async => const []),
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
  testWidgets('no info card is shown before any tap', (tester) async {
    await _pump(tester);
    expect(find.byType(TrackPointInfoCard), findsNothing);
  });

  testWidgets('tapping the drawn line shows a fix info card', (tester) async {
    await _pump(tester);
    // The camera fits the track, so its centre lies on the polyline.
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();
    expect(find.byType(TrackPointInfoCard), findsOneWidget);
  });

  testWidgets('the close button dismisses the info card', (tester) async {
    await _pump(tester);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();
    expect(find.byType(TrackPointInfoCard), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('track-inspect-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TrackPointInfoCard), findsNothing);
  });

  testWidgets('tapping away from the line dismisses the card', (tester) async {
    // The polyline GestureDetector defaulted to deferToChild, so a tap that
    // missed the drawn line never reached the handler and the card could
    // only be closed with its button. HitTestBehavior.translucent fixes it.
    await _pump(tester);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();
    expect(find.byType(TrackPointInfoCard), findsOneWidget);

    final topLeft = tester.getTopLeft(find.byType(FlutterMap));
    await tester.tapAt(topLeft + const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(find.byType(TrackPointInfoCard), findsNothing);
  });

  testWidgets('the inspected fix comes from the full list, not the LOD', (
    tester,
  ) async {
    // The simplified geometry keeps only the endpoints of this straight run,
    // so a card reporting a middle timestamp proves the lookup searched the
    // full decoded list.
    await _pumpDecimated(tester);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();

    final card = tester.widget<TrackPointInfoCard>(
      find.byType(TrackPointInfoCard),
    );
    expect(card.point.timestamp, isNot(_points.first.timestamp));
    expect(card.point.timestamp, isNot(_points.last.timestamp));
  });
}
