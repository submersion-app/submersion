import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/gpx/gpx_export_service.dart';
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

/// Returns a fixed result, or throws, so the page's three outcome branches
/// (cancel / success / failure) are each reachable without touching disk.
class _FakeGpxExportService implements GpxExportService {
  _FakeGpxExportService({this.result, this.fail = false});

  final String? result;
  final bool fail;
  int saveCalls = 0;

  @override
  String fileNameFor(GpsTrack track) => 'track.gpx';

  @override
  Future<String> shareTrack(GpsTrack track) async {
    if (fail) throw StateError('share failed');
    return result ?? '/tmp/track.gpx';
  }

  @override
  Future<String?> saveTrackToFile(GpsTrack track) async {
    saveCalls++;
    if (fail) throw StateError('save failed');
    return result;
  }
}

Future<void> _pump(WidgetTester tester, GpxExportService gpx) async {
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
        gpxExportServiceProvider.overrideWithValue(gpx),
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
  testWidgets('the overflow menu offers all four export entries', (
    tester,
  ) async {
    await _pump(tester, _FakeGpxExportService());
    await _openMenu(tester);

    expect(find.text('Share as GPX'), findsOneWidget);
    expect(find.text('Save as GPX...'), findsOneWidget);
    expect(find.text('Share as KML'), findsOneWidget);
    expect(find.text('Save as KML...'), findsOneWidget);
  });

  testWidgets('a cancelled save shows no confirmation', (tester) async {
    final gpx = _FakeGpxExportService(result: null);
    await _pump(tester, gpx);
    await _openMenu(tester);
    await tester.tap(find.text('Save as GPX...'));
    await tester.pumpAndSettle();

    // A cancel is not a failure and must not be reported as one.
    expect(gpx.saveCalls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a successful save confirms', (tester) async {
    await _pump(tester, _FakeGpxExportService(result: '/tmp/track.gpx'));
    await _openMenu(tester);
    await tester.tap(find.text('Save as GPX...'));
    await tester.pumpAndSettle();

    expect(find.text('Track saved'), findsOneWidget);
  });

  testWidgets('a throwing export shows a failure message', (tester) async {
    await _pump(tester, _FakeGpxExportService(fail: true));
    await _openMenu(tester);
    await tester.tap(find.text('Save as GPX...'));
    await tester.pumpAndSettle();

    expect(find.text('Export failed.'), findsOneWidget);
  });

  testWidgets('no overflow menu is shown for a missing track', (tester) async {
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackDetailProvider('track-1').overrideWith((ref) async => null),
          gpsTrackGeometryProvider((
            'track-1',
            TrackLod.detail,
          )).overrideWith((ref) async => const <GpsTrackPoint>[]),
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

    expect(find.byKey(const ValueKey('gps-track-overflow')), findsNothing);
  });
}
