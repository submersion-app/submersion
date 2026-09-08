import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
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
  bool notFound = false,
}) async {
  // A host locale the app actually translates into, so the English finders
  // below pass only because the MaterialApp pins `en`. Drop the pin and every
  // test in this file fails, which is the point: unpinned, they would pass on
  // en_US CI and fail on a translator's machine.
  tester.platformDispatcher.localesTestValue = const [
    Locale('fr'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final settings = MockSettingsNotifier(const AppSettings());
  final overrides = await getBaseOverrides(settingsNotifier: settings);
  final listCopy = createTestDiveWithBottomTime(id: 'd1');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        recentDivesProvider.overrideWith((ref) async => [listCopy]),
        diveProvider('d1').overrideWith((ref) async {
          if (error != null) throw error;
          if (notFound) return null;
          return listCopy.copyWith(profile: profile ?? const []);
        }),
      ].cast(),
      child: MaterialApp.router(
        // Pinned: every finder below matches an English literal, and an
        // unpinned MaterialApp resolves against the HOST's locale list, so
        // these pass on en_US CI and fail on a translator's machine.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: SizedBox(
                  width: 700,
                  height: 380,
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
  // The whole point of the slot: the home tab draws the same chart the dive
  // detail page draws, not a simplified rendition that drifts away from it.
  testWidgets('charts the newest dive with the dive-detail chart', (
    tester,
  ) async {
    await _pump(tester, profile: _profile());

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.text('Latest dive profile'), findsOneWidget);
  });

  // Manually logged dives carry no samples, and that is ordinary rather than
  // an error, so the slot explains itself instead of rendering an empty chart.
  testWidgets('falls back to a message when the dive has no profile', (
    tester,
  ) async {
    await _pump(tester, profile: null);

    expect(find.byType(DiveProfileChart), findsNothing);
    expect(find.text('No profile data for this dive'), findsOneWidget);
  });

  // A failed load and a dive that simply has no samples are different facts.
  // Reporting "no profile data" for a failure hides the error and tells the
  // diver something untrue about their dive.
  testWidgets('reports a load failure as an error, not as missing data', (
    tester,
  ) async {
    await _pump(tester, error: Exception('db unavailable'));

    expect(find.byType(DiveProfileChart), findsNothing);
    expect(find.text('No profile data for this dive'), findsNothing);
    expect(find.text("Couldn't load the dive profile"), findsOneWidget);
  });

  // "The dive is gone" and "the dive has no samples" are different facts, the
  // same way a load failure is. The newest dive can be deleted between the
  // recent-dives read and this one, and the list is about to drop it too, so
  // the slot collapses rather than describing a dive that no longer exists.
  testWidgets('collapses when the dive is not found, rather than claiming '
      'it has no profile', (tester) async {
    await _pump(tester, notFound: true);

    expect(find.byType(Card), findsNothing);
    expect(find.text('Latest dive profile'), findsNothing);
    expect(find.text('No profile data for this dive'), findsNothing);
  });

  // The button this slot gained with the full chart: the plot is small here,
  // so "give it the whole window" is the affordance that makes the slot
  // usable rather than merely accurate.
  testWidgets('opens the fullscreen profile from the header button', (
    tester,
  ) async {
    await _pump(tester, profile: _profile());

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenProfilePage), findsOneWidget);
  });

  // The home slot is a fixed-height box, and the full chart carries a legend
  // row (and, on a dive with tanks, a gas timeline strip) above its plot. If
  // that box is ever trimmed back to what the old static preview needed, the
  // chart overflows it rather than shrinking the plot to nothing.
  testWidgets('the full chart fits the height the home slot gives it', (
    tester,
  ) async {
    await _pump(tester, profile: _profile());

    expect(tester.takeException(), isNull);
    expect(find.byType(DiveProfileLegend), findsOneWidget);
    // The plot must still be the bulk of the slot once the legend has taken
    // its share, or the chart is there in name only.
    expect(
      tester.getSize(find.byType(LineChart).first).height,
      greaterThan(200),
    );
  });

  // The chart owns pan, zoom, tooltip and range gestures, so the card cannot
  // be one big tap target the way a static preview could be. The header is.
  testWidgets('opens the dive from the header, not from the chart', (
    tester,
  ) async {
    await _pump(tester, profile: _profile());

    await tester.tap(find.text('Latest dive profile'));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });
}
