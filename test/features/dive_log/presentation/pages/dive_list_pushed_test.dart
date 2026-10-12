import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/list_view_mode.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A dive list opened from a site, gear item, tag and so on is PUSHED over
/// the page that opened it (#2784, #3292). It shows a back arrow, and when it
/// goes away it puts back the dive-list filter and highlighted dive that were
/// in place before it opened.
void main() {
  const desktop = Size(1200, 800);
  const phone = Size(400, 800);

  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<({GoRouter router, ProviderContainer container})> pumpHarness(
    WidgetTester tester, {
    required Size size,
    required String initial,
    List<dynamic> extraOverrides = const [],
  }) async {
    final overrides = [
      ...await getBaseOverrides(),
      diveRepositoryProvider.overrideWithValue(repository),
      diveListNotifierProvider.overrideWith(
        (ref) => DiveListNotifier(repository, ref),
      ),
      paginatedDiveListProvider.overrideWith(
        (ref) => PaginatedDiveListNotifier(repository, ref),
      ),
      customTankPresetsProvider.overrideWith((ref) async => []),
      ...extraOverrides,
    ];

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        // Stands in for the Dive Activity Map: a page that is always pushed
        // and embeds the list without owning its back arrow.
        GoRoute(
          path: '/activity',
          builder: (_, _) => const Scaffold(
            body: DiveListContent(showAppBar: false, isMapMode: true),
          ),
        ),
        GoRoute(
          path: '/dives',
          builder: (_, state) => DiveListPage(
            returnTo: state.extra is DiveListReturn
                ? state.extra! as DiveListReturn
                : null,
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, _) => const Scaffold(body: Text('DIVE PAGE')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // ProviderScope (not an uncontrolled one) so the container is disposed
    // with the tree, before the test's pending-timer check.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    return (router: router, container: container);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  void setFilter(ProviderContainer c, String siteId) =>
      c.read(diveFilterProvider.notifier).state = DiveFilterState(
        siteId: siteId,
      );

  testWidgets('pushed list shows a back arrow that pops and restores the '
      'filter and highlight, even after a selection', (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.container.read(highlightedDiveIdProvider.notifier).state = 'orig';
    setFilter(h.container, 'other');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'mine'),
        highlightedDiveId: 'orig',
      ),
    );
    await settle(tester);
    expect(find.byType(BackButton), findsOneWidget);

    // A selection, as goInPlace does on a pushed page: replace() drops the
    // route's extra and swaps its completer, but keeps the page's State.
    h.container.read(highlightedDiveIdProvider.notifier).state = 'picked';
    h.router.replace('/dives?selected=picked');
    await settle(tester);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);

    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
    expect(h.container.read(highlightedDiveIdProvider), 'orig');
  });

  testWidgets('back over a table-mode list keeps its dive selected, not the '
      'one picked in the pushed list', (tester) async {
    // The table under the pushed list defers its highlight-to-URL sync while
    // covered and replays the GLOBAL highlight once uncovered. The restore
    // must land before that replay, or Back selects the wrong dive.
    final orig = await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'orig'),
    );
    final picked = await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'picked'),
    );
    final h = await pumpHarness(
      tester,
      size: desktop,
      initial: '/dives?selected=${orig.id}',
      extraOverrides: [
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.table),
        tableDetailsPaneProvider('dives').overrideWith((ref) => true),
      ],
    );
    h.container.read(highlightedDiveIdProvider.notifier).state = orig.id;
    await settle(tester);

    h.router.push(
      '/dives',
      extra: DiveListReturn(
        filter: h.container.read(diveFilterProvider),
        highlightedDiveId: orig.id,
      ),
    );
    await settle(tester);
    h.container.read(highlightedDiveIdProvider.notifier).state = picked.id;
    h.router.replace('/dives?selected=${picked.id}');
    await settle(tester);

    await tester.tap(find.byType(BackButton));
    await settle(tester);

    expect(h.router.canPop(), isFalse);
    expect(
      h.router.routerDelegate.currentConfiguration.uri.toString(),
      '/dives?selected=${orig.id}',
    );
    expect(h.container.read(highlightedDiveIdProvider), orig.id);
  });

  testWidgets('a pushed page embedding the list gets no back arrow from it', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push('/activity');
    await settle(tester);

    expect(
      find.byType(BackButton),
      findsNothing,
      reason: 'the embedding page owns its own way back',
    );
  });

  testWidgets('top-level list has no back arrow and restores nothing', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/dives');
    setFilter(h.container, 'kept');
    await settle(tester);

    expect(find.byType(BackButton), findsNothing);

    h.router.go('/root');
    await settle(tester);
    expect(h.container.read(diveFilterProvider).siteId, 'kept');
  });

  testWidgets('removed by go, the previous filter is still restored', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'mine'),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);
    setFilter(h.container, 'other');

    h.router.go('/root');
    await settle(tester);

    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
  });

  testWidgets('nested pushed lists unwind in order', (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'a'),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);
    setFilter(h.container, 'b');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'b'),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);
    setFilter(h.container, 'c');

    h.router.pop();
    await settle(tester);
    expect(h.container.read(diveFilterProvider).siteId, 'b');

    h.router.pop();
    await settle(tester);
    expect(h.container.read(diveFilterProvider).siteId, 'a');
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('toggling the map view on a pushed list keeps the way back', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);

    final mapToggle = find.byIcon(Icons.map);
    expect(mapToggle, findsWidgets);
    await tester.tap(mapToggle.first);
    await settle(tester);

    expect(h.router.canPop(), isTrue, reason: 'the map toggle must not go()');
  });

  testWidgets('phone width: the app bar back arrow pops and restores', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: phone, initial: '/root');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'mine'),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);
    setFilter(h.container, 'other');

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
  });

  testWidgets('phone map view: the back arrow pops a pushed list', (
    tester,
  ) async {
    final h = await pumpHarness(tester, size: phone, initial: '/root');
    h.router.push(
      '/dives?view=map',
      extra: const DiveListReturn(
        filter: DiveFilterState(),
        highlightedDiveId: null,
      ),
    );
    await settle(tester);

    // It returns to the page that opened the map, not to a dive list, so it
    // is labelled as a plain Back.
    expect(find.byTooltip('Back to dive list'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await settle(tester);

    expect(find.text('ROOT'), findsOneWidget);
  });
}
