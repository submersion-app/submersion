import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A shallow descent, a bottom leg, and an ascent, one sample per minute.
List<DiveProfilePoint> _profile() => [
  for (var minute = 0; minute <= 40; minute++)
    DiveProfilePoint(
      timestamp: minute * 60,
      depth: minute < 5
          ? minute * 6.0
          : minute < 30
          ? 30.0
          : 30.0 - (minute - 30) * 3.0,
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<DiveProfilePoint>? profile,
  Object? error,
  DepthUnit depthUnit = DepthUnit.meters,
}) async {
  final settings = MockSettingsNotifier(AppSettings(depthUnit: depthUnit));
  final overrides = await getBaseOverrides(settingsNotifier: settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        recentDivesProvider.overrideWith(
          (ref) async => [createTestDiveWithBottomTime(id: 'd1')],
        ),
        latestDiveProfileProvider.overrideWith((ref) async {
          if (error != null) throw error;
          return profile;
        }),
      ].cast(),
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: SizedBox(
                  width: 700,
                  height: 300,
                  child: RecentDiveProfilePreview(),
                ),
              ),
            ),
            GoRoute(
              path: '/dives/:id',
              builder: (context, state) => const Scaffold(body: Text('detail')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('charts the profile of the newest dive', (tester) async {
    await _pump(tester, profile: _profile());

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Latest dive profile'), findsOneWidget);
  });

  // Manually logged dives carry no samples, and that is ordinary rather than
  // an error, so the slot explains itself instead of rendering an empty chart.
  testWidgets('falls back to a message when the dive has no profile', (
    tester,
  ) async {
    await _pump(tester, profile: null);

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No profile data for this dive'), findsOneWidget);
  });

  // A failed load and a dive that simply has no samples are different facts.
  // Reporting "no profile data" for a failure hides the error and tells the
  // diver something untrue about their dive.
  testWidgets('reports a load failure as an error, not as missing data', (
    tester,
  ) async {
    await _pump(tester, error: Exception('db unavailable'));

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No profile data for this dive'), findsNothing);
    expect(find.text("Couldn't load the dive profile"), findsOneWidget);
  });

  testWidgets('plots depth in the diver\'s configured unit', (tester) async {
    await _pump(tester, profile: _profile(), depthUnit: DepthUnit.feet);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final deepest = chart.data.lineBarsData.single.spots
        .map((s) => -s.y)
        .reduce((a, b) => a > b ? a : b);

    // 30 m is ~98.4 ft; in metres the deepest plotted value would be 30.
    expect(deepest, greaterThan(90));
  });

  testWidgets('opens the dive when tapped', (tester) async {
    await _pump(tester, profile: _profile());

    await tester.tap(find.byType(RecentDiveProfilePreview));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });
}
