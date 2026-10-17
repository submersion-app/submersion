import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_scene.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_scene_markers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/scenes/water_column_painter.dart';

import '../../../../helpers/mock_providers.dart';

DiveStatistics _stats({
  int dives = 214,
  int seconds = 220800, // 61h 20m
  double maxDepth = 41.2,
  double avgMaxDepth = 18.4,
  int sites = 48,
  List<TopSiteStat>? topSites,
}) => DiveStatistics(
  totalDives: dives,
  totalTimeSeconds: seconds,
  maxDepth: maxDepth,
  avgMaxDepth: avgMaxDepth,
  totalSites: sites,
  topSites:
      topSites ??
      [TopSiteStat(siteId: 's1', siteName: 'Blue Hole', diveCount: 12)],
);

DiveRecords _deepest({String? siteName = 'Blue Hole', double depth = 41.2}) =>
    DiveRecords(
      deepestDive: DiveRecord(
        diveId: 'deep-1',
        siteName: siteName,
        dateTime: DateTime(2024, 3, 9),
        maxDepth: depth,
      ),
    );

Diver _diver({int? priorDives, int? priorSeconds}) => Diver(
  id: '1',
  name: 'Eric Griffin',
  priorDiveCount: priorDives,
  priorDiveTimeSeconds: priorSeconds,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late GoRouter router;

  Future<void> pumpScene(
    WidgetTester tester, {
    DiveStatistics? stats,
    DiveRecords? records,
    Diver? diver,
    DiveFilterState filter = const DiveFilterState(),
    DiveStatistics? scopedStats,
    AppSettings settings = const AppSettings(),
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(900, 700),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: DiveSummaryScene()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveFilterProvider.overrideWith((ref) => filter),
          diveStatisticsProvider.overrideWith((ref) async => stats ?? _stats()),
          diveRecordsProvider.overrideWith(
            (ref) async => records ?? _deepest(),
          ),
          diveListScopedStatisticsProvider.overrideWith(
            (ref) async => scopedStats ?? _stats(dives: 34, sites: 4),
          ),
          diveListScopedRecordsProvider.overrideWith(
            (ref) async => records ?? _deepest(),
          ),
          currentDiverProvider.overrideWith((ref) async => diver ?? _diver()),
        ].cast(),
        child: MaterialApp.router(
          theme: theme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    // The scene clock keeps ticking, so settle with a bounded pump.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows the dive count, time, site count and top site', (
    tester,
  ) async {
    await pumpScene(tester);

    expect(find.text('DIVES'), findsOneWidget);
    expect(find.text('214 dives · 61h 20m below'), findsOneWidget);
    expect(
      find.text('48 sites. You return most to Blue Hole.'),
      findsOneWidget,
    );
  });

  testWidgets('places the deepest dive as a marker that opens it in place', (
    tester,
  ) async {
    await pumpScene(tester);

    expect(find.text('41.2m'), findsOneWidget);
    expect(find.text('18.4m'), findsOneWidget);
    expect(find.text('your usual depth'), findsOneWidget);

    await tester.tap(find.textContaining('deepest, Blue Hole'));
    await tester.pump();

    expect(
      router.routeInformationProvider.value.uri.queryParameters['selected'],
      'deep-1',
    );
  });

  testWidgets(
    'a log with only prior dives shows the career count and no markers',
    (tester) async {
      await pumpScene(
        tester,
        stats: _stats(
          dives: 0,
          seconds: 0,
          maxDepth: 0,
          avgMaxDepth: 0,
          sites: 0,
          topSites: const [],
        ),
        records: DiveRecords(),
        diver: _diver(priorDives: 50, priorSeconds: 180000),
      );

      expect(find.text('50 dives · 50h 0m below'), findsOneWidget);
      expect(find.text('0 sites.'), findsOneWidget);
      expect(find.byType(DepthMarker), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
    },
  );

  testWidgets('reads depths in the diver unit', (tester) async {
    await pumpScene(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    expect(find.text('135.2ft'), findsOneWidget);
    expect(find.text('41.2m'), findsNothing);
    expect(find.text('18.4m'), findsNothing);
    expect(find.text('60.4ft'), findsOneWidget);
  });

  testWidgets('the depth scale ticks land on round numbers in metres', (
    tester,
  ) async {
    await pumpScene(tester);

    final scale = find.byKey(const ValueKey('scene-depth-scale'));
    for (final tick in ['0m', '20m', '40m']) {
      expect(
        find.descendant(of: scale, matching: find.text(tick)),
        findsOneWidget,
      );
    }
  });

  testWidgets('the depth scale ticks land on round numbers in feet', (
    tester,
  ) async {
    await pumpScene(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    final scale = find.byKey(const ValueKey('scene-depth-scale'));
    for (final tick in ['0ft', '100ft', '200ft']) {
      expect(
        find.descendant(of: scale, matching: find.text(tick)),
        findsOneWidget,
      );
    }
  });

  testWidgets('each marker hairline runs across the pane to the scale', (
    tester,
  ) async {
    await pumpScene(tester);

    final scaleLeft = tester
        .getRect(find.byKey(const ValueKey('scene-depth-scale')))
        .left;
    final lines = find.descendant(
      of: find.byType(DepthMarker),
      matching: find.byKey(const ValueKey('depth-marker-line')),
    );
    expect(lines, findsNWidgets(2));
    for (final element in lines.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.right, greaterThan(scaleLeft - 20));
    }
  });

  testWidgets('the deepest marker without a site shows the date alone', (
    tester,
  ) async {
    await pumpScene(tester, records: _deepest(siteName: null));

    final label = tester.widget<Text>(find.textContaining('deepest, '));
    expect(label.data, isNot(contains('null')));
    expect(label.data, isNot(contains(', ,')));
    expect(label.data, startsWith('deepest, '));
    expect(find.textContaining('Blue Hole,'), findsNothing);
  });

  testWidgets('describes the filtered list while a filter is active', (
    tester,
  ) async {
    await pumpScene(
      tester,
      filter: const DiveFilterState(siteIds: ['s1']),
      diver: _diver(priorDives: 125, priorSeconds: 360000),
    );

    expect(find.text('Filtered: summarizing 34 of 214 dives'), findsOneWidget);
    // Prior dives are left out under a filter (no filter can match them).
    expect(find.text('34 dives · 61h 20m below'), findsOneWidget);
    expect(find.text('4 sites. You return most to Blue Hole.'), findsOneWidget);
  });

  testWidgets('lays out without overflow at 400 x 400 and 1600 x 1000', (
    tester,
  ) async {
    for (final size in const [Size(400, 400), Size(1600, 1000)]) {
      await pumpScene(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('41.2m'), findsOneWidget, reason: '$size');
    }
  });

  testWidgets('puts the scale at the start edge in a right-to-left locale', (
    tester,
  ) async {
    await pumpScene(tester, locale: const Locale('ar'));

    final scale = tester.getRect(
      find.byKey(const ValueKey('scene-depth-scale')),
    );
    expect(scale.left, lessThan(900 / 2));
  });

  testWidgets('renders under every theme preset in both brightnesses', (
    tester,
  ) async {
    for (final preset in AppThemeRegistry.presets) {
      for (final theme in [preset.lightTheme, preset.darkTheme]) {
        await pumpScene(tester, theme: theme);
        expect(tester.takeException(), isNull, reason: preset.id);
        final paint = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is WaterColumnPainter,
          ),
        );
        expect(
          (paint.painter! as WaterColumnPainter).brightness,
          theme.brightness,
          reason: preset.id,
        );
      }
    }
  });
}
