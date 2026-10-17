import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_scene.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_summary_scene_facts_test.dart' show library;

void main() {
  late GoRouter router;

  Future<void> pumpScene(
    WidgetTester tester, {
    FutureOr<List<SiteWithDiveCount>> Function()? sites,
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

    final overrides = await getBaseOverrides();
    router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (_, _) => const Scaffold(body: SiteSummaryScene()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sitesWithCountsProvider.overrideWith(
            (ref) async => (sites ?? () => library)(),
          ),
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

  SiteWithDiveCount site(
    String id,
    String name, {
    int dives = 0,
    double? rating,
    String? country,
    DateTime? last,
  }) => SiteWithDiveCount(
    site: DiveSite(id: id, name: name, rating: rating, country: country),
    diveCount: dives,
    lastDivedAt: last,
  );

  testWidgets('shows the site and country counts and names the three sites', (
    tester,
  ) async {
    await pumpScene(tester);

    expect(find.text('DIVE SITES'), findsOneWidget);
    expect(find.text('5 sites, 3 countries'), findsOneWidget);
    expect(
      find.text(
        'Most dived: Blue Hole. Best rated: Blue Hole. '
        'Last dived: Cathedral.',
      ),
      findsOneWidget,
    );
    expect(find.text('Blue Hole · 9 dives'), findsOneWidget);
    expect(find.text('Cathedral · 3 dives'), findsOneWidget);
  });

  testWidgets('marks open their site in place', (tester) async {
    await pumpScene(tester);

    await tester.tap(find.text('Cathedral · 3 dives'));
    await tester.pump();

    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['selected'],
      'b',
    );
  });

  testWidgets('one site in every role draws one mark', (tester) async {
    await pumpScene(tester, sites: () => [library.first]);

    expect(find.byKey(const ValueKey('chart-mark-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-mark-1')), findsNothing);
    expect(
      find.text(
        'Most dived: Blue Hole. Best rated: Blue Hole. '
        'Last dived: Blue Hole.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the footer counts never-dived sites and leaves out zeros', (
    tester,
  ) async {
    await pumpScene(tester);

    expect(find.text('2 not yet dived'), findsOneWidget);
    expect(find.textContaining('with GPS'), findsNothing);
  });

  testWidgets('the footer joins GPS and never-dived counts', (tester) async {
    await pumpScene(
      tester,
      sites: () => [
        ...library,
        const SiteWithDiveCount(
          site: DiveSite(
            id: 'f',
            name: 'Gozo Arch',
            location: GeoPoint(36.05, 14.19),
          ),
          diveCount: 2,
        ),
      ],
    );

    expect(find.text('1 with GPS · 2 not yet dived'), findsOneWidget);
  });

  testWidgets('a library where every site is dived and none has GPS has no '
      'footer', (tester) async {
    await pumpScene(tester, sites: () => library.sublist(0, 3));

    expect(find.textContaining('not yet dived'), findsNothing);
    expect(find.textContaining('with GPS'), findsNothing);
  });

  testWidgets('sites with no country leave the country out', (tester) async {
    await pumpScene(
      tester,
      sites: () => [site('x', 'Reef', dives: 1, last: DateTime(2026))],
    );

    expect(find.text('1 site'), findsOneWidget);
  });

  testWidgets('an unrated library uses the unrated sentence', (tester) async {
    await pumpScene(
      tester,
      sites: () => [
        site('x', 'Reef', dives: 4, last: DateTime(2025)),
        site('y', 'Wall', dives: 1, last: DateTime(2026)),
      ],
    );

    expect(find.text('Most dived: Reef. Last dived: Wall.'), findsOneWidget);
  });

  testWidgets('a rated but undived library names the best rated site', (
    tester,
  ) async {
    await pumpScene(tester, sites: () => [site('x', 'Reef', rating: 4)]);

    expect(find.text('Best rated: Reef. None dived yet.'), findsOneWidget);
    expect(find.text('Reef'), findsNothing);
    expect(find.text('Reef · 0 dives'), findsOneWidget);
  });

  testWidgets('an undived, unrated library says it is waiting', (tester) async {
    await pumpScene(tester, sites: () => [site('x', 'Reef')]);

    expect(find.text('Saved, and waiting for a first dive.'), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-mark-0')), findsNothing);
  });

  testWidgets('while loading only the eyebrow shows', (tester) async {
    final never = Completer<List<SiteWithDiveCount>>();
    await pumpScene(tester, sites: () => never.future);

    expect(find.text('DIVE SITES'), findsOneWidget);
    expect(find.textContaining('sites,'), findsNothing);
  });

  testWidgets('an error shows the eyebrow only', (tester) async {
    await pumpScene(tester, sites: () => throw StateError('db'));

    expect(find.text('DIVE SITES'), findsOneWidget);
    expect(find.textContaining('sites,'), findsNothing);
    expect(find.byKey(const ValueKey('chart-mark-0')), findsNothing);
  });

  testWidgets('lays out without overflow at the three sizes', (tester) async {
    final long = [
      site(
        'x',
        'The Long Named Wall at Rapid Bay Jetty, South Australia',
        dives: 40,
        rating: 5,
        country: 'Australia',
        last: DateTime(2026),
      ),
      ...library,
    ];
    for (final size in const [
      Size(400, 400),
      Size(900, 700),
      Size(1600, 1000),
    ]) {
      await pumpScene(tester, size: size, sites: () => long);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('a narrow pane shortens mark labels to the site name', (
    tester,
  ) async {
    await pumpScene(tester, size: const Size(400, 400));

    expect(find.text('Cathedral'), findsOneWidget);
    expect(find.text('Cathedral · 3 dives'), findsNothing);
  });

  testWidgets('in Arabic the headline aligns right and the marks do not '
      'move', (tester) async {
    await pumpScene(tester);
    final english = tester.getRect(find.byKey(const ValueKey('chart-mark-0')));

    await pumpScene(tester, locale: const Locale('ar'));

    final eyebrow = tester.getRect(find.byType(SceneEyebrow));
    expect(eyebrow.left, greaterThan(900 * 0.5));
    expect(eyebrow.right, closeTo(900 * (1 - 0.075), 1));
    // The picture does not mirror: each mark keeps its horizontal place.
    // Its height follows the headline, which is taller in Arabic.
    final arabic = tester.getRect(find.byKey(const ValueKey('chart-mark-0')));
    expect(arabic.left, english.left);
    expect(arabic.right, english.right);
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
            (w) => w is CustomPaint && w.painter is ChartPainter,
          ),
        );
        expect(
          (paint.painter! as ChartPainter).brightness,
          theme.brightness,
          reason: preset.id,
        );
      }
    }
  });
}
