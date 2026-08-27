import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t, double lat) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: 0.0);

Future<void> _pump(
  WidgetTester tester,
  List<GpsTrackPoint> points, {
  int diveCount = 0,
}) async {
  final base = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(900, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackStatsHeader(points: points, diveCount: diveCount),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reports fix count and dive count', (tester) async {
    await _pump(tester, [
      p(0, 0.0),
      p(600, 0.001),
      p(1200, 0.002),
    ], diveCount: 2);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('reports duration in compact form', (tester) async {
    // 0 to 3600 s = exactly one hour.
    await _pump(tester, [p(0, 0.0), p(3600, 0.01)]);
    expect(find.text('1h 0m'), findsOneWidget);
  });

  testWidgets('renders zeroed stats for an empty track without throwing', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.byType(TrackStatsHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a single-fix track without dividing by zero', (
    tester,
  ) async {
    await _pump(tester, [p(0, 0.0)]);
    expect(tester.takeException(), isNull);
    // Duration is undefined for one fix; it must not render as 0h 0m.
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrackStatsHeader(
              points: [p(0, 0.0), p(3600, 0.01)],
              diveCount: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
