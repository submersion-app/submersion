import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t) => GpsTrackPoint(
  timestamp: 1700000000 + t * 3600,
  latitude: 20.0 + t * 0.01,
  longitude: -87.0,
);

final _points = [p(0), p(1), p(2), p(3), p(4)];

GpsTrack _track({int? trimStart, int? trimEnd}) => GpsTrack(
  id: 'track-1',
  startTime: _points.first.timestamp * 1000,
  endTime: _points.last.timestamp * 1000,
  pointCount: _points.length,
  points: _points,
  trimStartTime: trimStart,
  trimEndTime: trimEnd,
);

Future<void> _pump(WidgetTester tester, {GpsTrack? track}) async {
  final base = await getBaseOverrides();
  final t = track ?? _track();
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackDetailProvider('track-1').overrideWith((ref) async => t),
        gpsTrackGeometryProvider((
          'track-1',
          TrackLod.detail,
        )).overrideWith((ref) async => t.effectivePoints),
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

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no edit panel is shown by default', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsNothing);
  });

  testWidgets('Trim shows a range scrubber and an Apply action', (
    tester,
  ) async {
    await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Trim...'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsOneWidget);
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Apply trim'), findsOneWidget);
  });

  testWidgets('Trim does not warn, because it is reversible', (tester) async {
    await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Trim...'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be undone'),
      findsNothing,
      reason: 'trim writes bounds only and is fully reversible',
    );
  });

  testWidgets('Split warns that the operation is destructive', (tester) async {
    await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Split...'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(
      find.text(
        'Splitting creates two tracks and removes the original. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Split here'), findsOneWidget);
  });

  testWidgets('Reset trim is absent when the track has no bounds', (
    tester,
  ) async {
    await _pump(tester);
    await _openMenu(tester);
    expect(find.text('Reset trim'), findsNothing);
  });

  testWidgets('Reset trim appears once the track has bounds', (tester) async {
    await _pump(tester, track: _track(trimStart: (1700000000 + 3600) * 1000));
    await _openMenu(tester);
    expect(find.text('Reset trim'), findsOneWidget);
  });

  testWidgets('Cancel leaves edit mode without applying', (tester) async {
    await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Trim...'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gps-track-edit-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsNothing);
  });
}
