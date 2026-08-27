import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int h) => GpsTrackPoint(
  timestamp: DateTime.utc(2026, 5, 22, 8 + h).millisecondsSinceEpoch ~/ 1000,
  latitude: 20.0 + h * 0.01,
  longitude: -87.0,
);

final _points = [p(0), p(1), p(2), p(3), p(4)];

GpsTrack _track({int? trimStart}) => GpsTrack(
  id: 'track-1',
  startTime: _points.first.timestamp * 1000,
  endTime: _points.last.timestamp * 1000,
  pointCount: _points.length,
  points: _points,
  trimStartTime: trimStart,
);

/// Captures what the page asks the trim provider to write.
typedef TrimCall = ({String id, int? startMs, int? endMs});

Future<List<TrimCall>> _pump(WidgetTester tester, {GpsTrack? track}) async {
  final base = await getBaseOverrides();
  final calls = <TrimCall>[];
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
        trimTrackProvider.overrideWithValue((
          String id, {
          int? startMs,
          int? endMs,
        }) async {
          calls.add((id: id, startMs: startMs, endMs: endMs));
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
  return calls;
}

Future<void> _chooseTrim(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Trim...'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Apply without dragging does not clear an existing trim', (
    tester,
  ) async {
    // Regression: pending bounds started null, so Apply wrote (null, null) -
    // byte-identical to clearTrim - erasing the user's trim and syncing the
    // erasure.
    final trimStart = DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch;
    final calls = await _pump(tester, track: _track(trimStart: trimStart));

    await _chooseTrim(tester);
    await tester.tap(find.byKey(const ValueKey('gps-track-edit-apply')));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(
      calls.single.startMs,
      isNotNull,
      reason: 'a null start is indistinguishable from Reset trim',
    );
    expect(calls.single.endMs, isNotNull);
  });

  testWidgets('Apply without dragging preserves the visible span', (
    tester,
  ) async {
    final calls = await _pump(tester);

    await _chooseTrim(tester);
    await tester.tap(find.byKey(const ValueKey('gps-track-edit-apply')));
    await tester.pumpAndSettle();

    // What the scrubber showed: the whole track.
    expect(calls.single.startMs, _points.first.timestamp * 1000);
    expect(calls.single.endMs, _points.last.timestamp * 1000);
  });

  testWidgets('Reset trim still clears both bounds', (tester) async {
    final trimStart = DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch;
    final calls = await _pump(tester, track: _track(trimStart: trimStart));

    await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset trim'));
    await tester.pumpAndSettle();

    expect(calls.single.startMs, isNull);
    expect(calls.single.endMs, isNull);
  });

  testWidgets('edit mode does not leak to the next track opened', (
    tester,
  ) async {
    // trackEditModeProvider is autoDispose, so leaving the page by any route
    // resets it. A plain StateProvider left the panel open on track B.
    await _pump(tester);
    await _chooseTrim(tester);
    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsOneWidget);

    // Tear the page down entirely, as a back navigation would.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pump(tester);
    expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsNothing);
  });
}
