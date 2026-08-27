import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Weekday axis as driven from Advanced Search. The page keeps its own draft
/// copy of every filter and only writes it back on Search, so the seeding,
/// the section auto-expansion and the write-back all need exercising here
/// rather than through [WeekdayFilterSelector] alone.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> pumpSearchPage(
    WidgetTester tester, {
    required DiveFilterState initial,
  }) async {
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/dives/search',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: Text('dive list')),
          routes: [
            GoRoute(path: 'search', builder: (_, _) => const DiveSearchPage()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveFilterProvider.overrideWith((ref) => initial),
        ].cast(),
        child: MaterialApp.router(
          // Pinned: this suite drives the page by English label.
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  /// The page's sections build lazily, so a target below the fold has no
  /// element for `ensureVisible` to work from. Scroll incrementally instead,
  /// which keeps the list building content as it goes.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  Finder weekdayChips() => find.descendant(
    of: find.byType(WeekdayFilterSelector),
    matching: find.byType(FilterChip),
  );

  testWidgets('a seeded weekday filter auto-expands the date section', (
    tester,
  ) async {
    // Weekdays alone, with no date range, still has to open the section that
    // holds them, or the diver cannot see the filter that is in force.
    await pumpSearchPage(
      tester,
      initial: const DiveFilterState(weekdays: [DateTime.tuesday]),
    );

    await scrollTo(tester, find.byType(WeekdayFilterSelector));

    final chips = tester.widgetList<FilterChip>(weekdayChips());
    expect(chips.where((c) => c.selected).length, 1);
    expect(find.text('Clear weekdays'), findsOneWidget);
  });

  testWidgets('tapping a chip then Search writes the weekday back', (
    tester,
  ) async {
    final container = await pumpSearchPage(
      tester,
      initial: const DiveFilterState(weekdays: [DateTime.tuesday]),
    );

    await scrollTo(tester, find.byType(WeekdayFilterSelector));

    // en_US is Sunday-first, so the first chip is Sunday, which the seed
    // leaves unselected.
    await tester.tap(weekdayChips().first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(
      container.read(diveFilterProvider).weekdays,
      containsAll(<int>[DateTime.tuesday, DateTime.sunday]),
    );
  });

  testWidgets('Clear weekdays drops the axis on Search', (tester) async {
    final container = await pumpSearchPage(
      tester,
      initial: const DiveFilterState(
        weekdays: [DateTime.monday, DateTime.thursday],
      ),
    );

    await scrollTo(tester, find.text('Clear weekdays'));
    await tester.tap(find.text('Clear weekdays'));
    await tester.pumpAndSettle();

    expect(find.text('Clear weekdays'), findsNothing);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(container.read(diveFilterProvider).weekdays, isEmpty);
  });

  testWidgets('Clear All drops a seeded weekday selection', (tester) async {
    await pumpSearchPage(
      tester,
      initial: const DiveFilterState(weekdays: [DateTime.saturday]),
    );

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(WeekdayFilterSelector));
    final chips = tester.widgetList<FilterChip>(weekdayChips());
    expect(chips.where((c) => c.selected), isEmpty);
    expect(find.text('Clear weekdays'), findsNothing);
  });
}
