import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/dive_log/query/dive_number_query.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show makeDive;
import 'dive_scrubber_index_override.dart';

/// A first page of [all]; [loadUntil] loads through the dive asked for, as
/// the real one does once the cleared search has reloaded.
class _JumpNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _JumpNotifier(this.all)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: all.take(50).toList(),
            totalCount: all.length,
            revision: 1,
          ),
        ),
      );

  final List<DiveSummary> all;
  final asked = <String>[];

  /// When set, [loadUntil] waits on it, as a long log's reads do.
  Completer<void>? gate;

  /// When true, [loadUntil] fails, as a read the database refuses does.
  bool fail = false;

  @override
  Future<bool> loadUntil(String diveId) async {
    asked.add(diveId);
    await gate?.future;
    if (fail) throw StateError('load failed');
    final index = all.indexWhere((d) => d.id == diveId);
    if (index < 0) return false;
    final through = (index + 51).clamp(0, all.length);
    state = AsyncValue.data(
      state.value!.copyWith(
        dives: all.take(through).toList(),
        hasMore: through < all.length,
      ),
    );
    return true;
  }

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Newest first, as the list shows them: d300 at the top, d1 at the end.
  final rows = [for (var n = 300; n >= 1; n--) makeDive('d$n')];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_JumpNotifier> pumpList(
    WidgetTester tester, {
    List<DiveSummary>? dives,
    bool grouping = false,
    Map<String, int> tripCounts = const {},
    List<String> collapsed = const [],
    void Function(String? id)? onSelected,
    GoRouter Function(Widget list)? router,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final all = dives ?? rows;
    final notifier = _JumpNotifier(all);
    final base = await getBaseOverrides();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kCollapsedTripIdsPrefsKey, collapsed);
    final overrides = [
      ...base,
      diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
      diveListGroupTripsProvider.overrideWith((ref) => grouping),
      tripDiveCountsProvider.overrideWith((ref) async => tripCounts),
      collapsedTripIdsProvider.overrideWith(
        (ref) => CollapsedTripsNotifier(prefs, null),
      ),
      paginatedDiveListProvider.overrideWith((ref) => notifier),
      diveScrubberIndexOverride(
        () => [
          for (final d in all)
            DiveScrubberEntry(
              id: d.id,
              sortTimestamp: d.sortTimestamp,
              diveNumber: d.diveNumber,
              siteName: d.siteName,
              tripId: d.tripId,
              tripName: d.tripName,
            ),
        ],
      ),
      diveSearchBarOpenProvider.overrideWith((ref) => true),
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      // The numbered dive leads, then a text match, as the real rows do.
      diveJumpResultsProvider.overrideWith((ref, q) async {
        final number = bareDiveNumber(q);
        return [...all.where((d) => d.diveNumber == number), all.first];
      }),
      savedQueryLoadsProvider('dives').overrideWith((ref) async => []),
      recentQueriesProvider.overrideWith((ref) async => []),
      allBuddiesProvider.overrideWith((ref) async => const <Buddy>[]),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'ana'),
      recentTypedRecorderProvider.overrideWithValue(
        (text, node, locale, diverId) async {},
      ),
    ];
    if (router == null) {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: DiveListContent(
            showAppBar: false,
            onItemSelected: onSelected ?? (_) {},
          ),
        ),
      );
    } else {
      // A phone: opening a dive pushes its page over the list.
      final config = router(
        const Scaffold(body: DiveListContent(showAppBar: false)),
      );
      addTearDown(config.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: config,
          ),
        ),
      );
    }
    await settle(tester);
    return notifier;
  }

  Finder row(String id) => find.byWidgetPredicate(
    (w) => w is KeyboardListItem && w.navigationKey == id,
  );

  Rect listRect(WidgetTester tester) =>
      tester.getRect(find.byType(CustomScrollView));

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiveListContent)));

  /// The list at /dives, each dive's page pushed over it at /dives/:id.
  GoRouter phoneRouter(Widget list) => GoRouter(
    initialLocation: '/dives',
    routes: [
      GoRoute(
        path: '/dives',
        builder: (_, _) => list,
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('DIVE ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );

  Future<void> typeNumber(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(kDiveSearchFieldKey), text);
    await tester.pump(kDiveSearchDebounce);
    await settle(tester);
  }

  group('a typed dive number lands the list on that dive (#3744)', () {
    testWidgets('Enter loads the dive in and puts its row on screen', (
      tester,
    ) async {
      String? selected;
      final notifier = await pumpList(
        tester,
        onSelected: (id) => selected = id,
      );
      // Dive 100 is the 201st row, far past the first page.
      expect(row('d100'), findsNothing);

      await typeNumber(tester, '100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      expect(notifier.asked, ['d100']);
      expect(selected, 'd100');
      expect(
        container(tester).read(diveFilterProvider).hasActiveFilters,
        isFalse,
      );
      // On the dive itself, not somewhere around it: its row is whole and
      // on screen, at the top of the list.
      expect(row('d100'), findsOneWidget);
      final list = listRect(tester);
      final target = tester.getRect(row('d100'));
      expect(target.top, moreOrLessEquals(list.top, epsilon: 1));
      expect(target.bottom, lessThanOrEqualTo(list.bottom));
    });

    testWidgets('tapping the numbered row lands the same way', (tester) async {
      String? selected;
      await pumpList(tester, onSelected: (id) => selected = id);

      await typeNumber(tester, '#30');
      await tester.tap(find.byKey(const ValueKey('dive-jump-d30')));
      await settle(tester);

      expect(selected, 'd30');
      final list = listRect(tester);
      final target = tester.getRect(row('d30'));
      expect(target.top, moreOrLessEquals(list.top, epsilon: 1));
    });

    testWidgets('a text match row only opens its dive', (tester) async {
      String? selected;
      final notifier = await pumpList(
        tester,
        onSelected: (id) => selected = id,
      );

      await typeNumber(tester, '100');
      await tester.tap(find.byKey(const ValueKey('dive-jump-d300')));
      await settle(tester);

      expect(selected, 'd300');
      expect(notifier.asked, isEmpty);
    });

    testWidgets('a dive in a folded trip opens the trip and shows the row', (
      tester,
    ) async {
      // d150 to d170 are one trip, folded, well past the first page.
      final dives = [
        for (var n = 300; n >= 1; n--)
          n >= 150 && n <= 170
              ? makeDive('d$n', tripId: 't1', tripName: 'Red Sea')
              : makeDive('d$n'),
      ];
      await pumpList(
        tester,
        dives: dives,
        grouping: true,
        tripCounts: const {'t1': 21},
        collapsed: const ['t1'],
      );

      await typeNumber(tester, '160');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      expect(
        container(tester).read(collapsedTripIdsProvider),
        isNot(contains('t1')),
      );
      final list = listRect(tester);
      final target = tester.getRect(row('d160'));
      expect(target.top, greaterThanOrEqualTo(list.top - 0.5));
      expect(target.bottom, lessThanOrEqualTo(list.bottom + 0.5));
    });

    testWidgets('a scroll by hand while the dive loads keeps the list put', (
      tester,
    ) async {
      final notifier = await pumpList(tester);
      notifier.gate = Completer<void>();

      await typeNumber(tester, '100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await settle(tester);
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final before = position.pixels;

      notifier.gate!.complete();
      await settle(tester);

      expect(notifier.asked, ['d100']);
      expect(position.pixels, before);
      expect(row('d100'), findsNothing);
    });

    testWidgets('a failed load still opens the dive and leaves the list', (
      tester,
    ) async {
      String? selected;
      final notifier = await pumpList(
        tester,
        onSelected: (id) => selected = id,
      );
      notifier.fail = true;

      await typeNumber(tester, '100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      expect(notifier.asked, ['d100']);
      expect(selected, 'd100');
      expect(row('d100'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a phone, back from the opened dive shows its row', (
      tester,
    ) async {
      late GoRouter router;
      final notifier = await pumpList(
        tester,
        router: (list) => router = phoneRouter(list),
      );

      // A load slower than a page transition, as a long log's reads are:
      // the dive opens once the list under it has landed.
      notifier.gate = Completer<void>();
      await typeNumber(tester, '100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('DIVE d100'), findsNothing);
      notifier.gate!.complete();
      await settle(tester);
      expect(find.text('DIVE d100'), findsOneWidget);

      router.pop();
      await settle(tester);

      final list = listRect(tester);
      final target = tester.getRect(row('d100'));
      expect(target.top, greaterThanOrEqualTo(list.top - 0.5));
      expect(target.bottom, lessThanOrEqualTo(list.bottom + 0.5));
    });

    testWidgets('on a phone, a failed load still opens the dive', (
      tester,
    ) async {
      final notifier = await pumpList(tester, router: phoneRouter);
      notifier.fail = true;

      await typeNumber(tester, '100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      expect(find.text('DIVE d100'), findsOneWidget);
    });
  });
}
