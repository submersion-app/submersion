import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression coverage for #1079: opening Advanced Search from the Statistics
/// tab used to hijack the dive-list filter and dump the user on the dive list.
/// The page now targets whichever filter provider opened it, and returns to
/// the surface it was pushed from unless that surface is the dive list.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<Override>> buildOverrides() async {
    final overrides = await getBaseOverrides();
    return [
      ...overrides,
      // Two distinct seeds so an assertion can tell which provider the page
      // read from and which one it wrote back to.
      diveFilterProvider.overrideWith(
        (ref) => const DiveFilterState(minRating: 2),
      ),
      statisticsFilterProvider.overrideWith(
        (ref) => const DiveFilterState(minRating: 4),
      ),
    ].cast<Override>();
  }

  GoRouter buildRouter({
    required String initialLocation,
    void Function(Object? extra)? onSearchExtra,
    Widget Function(BuildContext context)? statisticsBuilder,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: Text('dive list')),
          routes: [
            GoRoute(
              path: 'search',
              builder: (context, state) {
                onSearchExtra?.call(state.extra);
                return DiveSearchPage(
                  filterProvider: state.extra is StateProvider<DiveFilterState>
                      ? state.extra as StateProvider<DiveFilterState>
                      : null,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, _) =>
              statisticsBuilder?.call(context) ??
              const Scaffold(body: Text('statistics')),
        ),
      ],
    );
  }

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required GoRouter router,
    required List<Override> overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// Set the minimum-rating filter to five stars so the applied filter differs
  /// from both seeds, making the write target unambiguous.
  Future<void> tapFiveStars(WidgetTester tester) async {
    // The Organization section auto-expands because both seeds set a rating,
    // but the star row sits far enough below the viewport that the plain
    // ListView hasn't built its element yet, so `ensureVisible` (which needs
    // an existing element) can't find it. Scroll incrementally instead so
    // the list keeps building content as it goes.
    final fiveStars = find.byTooltip('5 stars');
    await tester.scrollUntilVisible(
      fiveStars,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(fiveStars);
    await tester.pumpAndSettle();
  }

  testWidgets('applies to the statistics filter and returns to statistics', (
    tester,
  ) async {
    final overrides = await buildOverrides();
    final router = buildRouter(initialLocation: '/statistics');
    await pumpApp(tester, router: router, overrides: overrides);

    router.push('/dives/search', extra: statisticsFilterProvider);
    await tester.pumpAndSettle();
    expect(find.byType(DiveSearchPage), findsOneWidget);

    await tapFiveStars(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final container = containerOf(tester);
    expect(container.read(statisticsFilterProvider).minRating, 5);
    expect(container.read(diveFilterProvider).minRating, 2);
    expect(find.text('statistics'), findsOneWidget);
    expect(find.byType(DiveSearchPage), findsNothing);
  });

  testWidgets('applies to the dive filter and navigates to the dive list', (
    tester,
  ) async {
    final overrides = await buildOverrides();
    final router = buildRouter(initialLocation: '/dives');
    await pumpApp(tester, router: router, overrides: overrides);

    router.push('/dives/search');
    await tester.pumpAndSettle();
    expect(find.byType(DiveSearchPage), findsOneWidget);

    await tapFiveStars(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final container = containerOf(tester);
    expect(container.read(diveFilterProvider).minRating, 5);
    expect(container.read(statisticsFilterProvider).minRating, 4);
    expect(find.text('dive list'), findsOneWidget);
  });

  testWidgets('a section-targeted page with nothing to pop falls back to the '
      'dive list', (tester) async {
    // Only reachable from a hand-built route or a stale deep link, since the
    // sections always push. The page must still lead somewhere.
    final overrides = await buildOverrides();
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: Text('dive list')),
        ),
        GoRoute(
          path: '/search',
          builder: (_, _) =>
              DiveSearchPage(filterProvider: statisticsFilterProvider),
        ),
      ],
    );
    await pumpApp(tester, router: router, overrides: overrides);
    expect(find.byType(DiveSearchPage), findsOneWidget);

    await tapFiveStars(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(statisticsFilterProvider).minRating, 5);
    expect(find.text('dive list'), findsOneWidget);
  });

  testWidgets('the filter sheet forwards its target provider to the page', (
    tester,
  ) async {
    final overrides = await buildOverrides();
    Object? capturedExtra;
    final router = buildRouter(
      initialLocation: '/statistics',
      onSearchExtra: (extra) => capturedExtra = extra,
      statisticsBuilder: (context) => Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DiveFilterSheet(
                  ref: ref,
                  filterProvider: statisticsFilterProvider,
                ),
              ),
              child: const Text('open filter'),
            ),
          ),
        ),
      ),
    );
    await pumpApp(tester, router: router, overrides: overrides);

    await tester.tap(find.text('open filter'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsOneWidget);

    await tester.tap(find.byIcon(Icons.manage_search));
    await tester.pumpAndSettle();

    expect(capturedExtra, same(statisticsFilterProvider));
    expect(find.byType(DiveSearchPage), findsOneWidget);
  });
}
