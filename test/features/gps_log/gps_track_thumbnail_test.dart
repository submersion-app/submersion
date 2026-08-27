import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: t,
  latitude: 20.0 + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<GpsTrackPoint> geometry,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.thumbnail,
        )).overrideWith((ref) async => geometry),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: GpsTrackThumbnail(trackId: 'track-1')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders at exactly 88x64', (tester) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final size = tester.getSize(find.byType(GpsTrackThumbnail));
    expect(size.width, kTrackThumbnailWidth);
    expect(size.height, kTrackThumbnailHeight);
  });

  testWidgets('renders a non-interactive map when geometry is available', (
    tester,
  ) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags, InteractiveFlag.none);
  });

  testWidgets('clamps the camera fit to a low shared-tile zoom', (
    tester,
  ) async {
    // Three fixes within a few hundred metres would otherwise fit at zoom
    // ~17, fetching tiles no sibling row could share.
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final fit = map.options.initialCameraFit;
    expect(fit, isA<FitBounds>());
    expect((fit as FitBounds).maxZoom, 12.0);
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await _pump(tester, geometry: [p(0), p(1), p(2)]);
    expect(
      find.ancestor(
        of: find.byType(FlutterMap),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('falls back to the shape chip for an empty track', (
    tester,
  ) async {
    await _pump(tester, geometry: const []);
    expect(find.byType(TrackShapeChip), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('falls back to the shape chip for a single-fix track', (
    tester,
  ) async {
    await _pump(tester, geometry: [p(0)]);
    expect(find.byType(TrackShapeChip), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('shows the shape chip while geometry is still loading', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackGeometryProvider((
            'track-1',
            TrackLod.thumbnail,
          )).overrideWith(
            (ref) => Future.delayed(
              const Duration(seconds: 5),
              () => <GpsTrackPoint>[],
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: GpsTrackThumbnail(trackId: 'track-1')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TrackShapeChip), findsOneWidget);
    // Drain the pending timer so the test does not fail on a live timer.
    await tester.pump(const Duration(seconds: 6));
  });
}
