import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Stands in for the real paginated notifier, and counts page requests so the
/// collapsed-page case can prove the list keeps asking.
class MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  MockPaginatedNotifier(List<DiveSummary> dives, {bool hasMore = false})
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: hasMore)),
      );

  int loadNextPageCalls = 0;

  /// Pages this mock still has to hand out before it reports exhaustion.
  int pagesRemaining = 0;

  /// Rows appended per page, so a caller can simulate a page that is entirely
  /// inside a collapsed group.
  List<DiveSummary> Function(int page)? nextPageBuilder;

  /// Mirrors the real notifier closely enough to be honest about paging: it
  /// flips isLoadingMore, then either appends a page or reports exhaustion.
  /// A mock that only counted calls would never settle, because the list
  /// re-kicks every frame until the state moves.
  @override
  Future<void> loadNextPage() async {
    loadNextPageCalls++;
    final current = state.value ?? const PaginatedDiveListState();
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    if (pagesRemaining <= 0) {
      state = AsyncValue.data(
        current.copyWith(isLoadingMore: false, hasMore: false),
      );
      return;
    }

    pagesRemaining--;
    final appended = nextPageBuilder?.call(loadNextPageCalls) ?? const [];
    state = AsyncValue.data(
      current.copyWith(
        dives: [...current.dives, ...appended],
        isLoadingMore: false,
        hasMore: pagesRemaining > 0,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveSummary makeDive(String id, {String? tripId, String? tripName}) {
  return DiveSummary(
    id: id,
    diveNumber: int.parse(id.substring(1)),
    name: 'Dive $id',
    dateTime: DateTime(2026, 6, 8),
    // The detailed tile titles on the site, so fixtures need one to be
    // findable by text.
    siteName: 'Site $id',
    sortTimestamp: 0,
    tripId: tripId,
    tripName: tripName,
    tripStartDate: tripId == null ? null : DateTime(2026, 6, 8),
    tripEndDate: tripId == null ? null : DateTime(2026, 6, 9),
  );
}

Future<List<Override>> groupingOverrides(
  List<DiveSummary> dives, {
  bool grouping = true,
  Map<String, int> tripTotals = const {},
  MockPaginatedNotifier? notifier,
  ListViewMode viewMode = ListViewMode.detailed,
}) async {
  final base = await getBaseOverrides();
  return [
    ...base,
    diveListViewModeProvider.overrideWith((ref) => viewMode),
    diveListGroupTripsProvider.overrideWith((ref) => grouping),
    tripDiveCountsProvider.overrideWith((ref) async => tripTotals),
    paginatedDiveListProvider.overrideWith(
      (ref) => notifier ?? MockPaginatedNotifier(dives),
    ),
  ];
}

void main() {
  group('dive list trip grouping', () {
    testWidgets('a trip header appears above its dives', (tester) async {
      final overrides = await groupingOverrides(
        [
          makeDive('d1'),
          makeDive('d2', tripId: 't1', tripName: 'Tassie'),
          makeDive('d3', tripId: 't1', tripName: 'Tassie'),
        ],
        tripTotals: const {'t1': 2},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
      expect(find.text('Tassie'), findsOneWidget);
    });

    testWidgets('grouped dive cards are exactly as wide as loose ones', (
      tester,
    ) async {
      final overrides = await groupingOverrides(
        [makeDive('d1'), makeDive('d2', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      final loose = tester.getSize(
        find
            .ancestor(of: find.text('Site d1'), matching: find.byType(Card))
            .first,
      );
      final grouped = tester.getSize(
        find
            .ancestor(of: find.text('Site d2'), matching: find.byType(Card))
            .first,
      );

      expect(
        grouped.width,
        loose.width,
        reason: 'grouping must never narrow a dive card (#1193)',
      );
    });

    testWidgets('grouped and loose cards share the same left edge', (
      tester,
    ) async {
      final overrides = await groupingOverrides(
        [makeDive('d1'), makeDive('d2', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      final loose = tester.getTopLeft(
        find
            .ancestor(of: find.text('Site d1'), matching: find.byType(Card))
            .first,
      );
      final grouped = tester.getTopLeft(
        find
            .ancestor(of: find.text('Site d2'), matching: find.byType(Card))
            .first,
      );

      expect(grouped.dx, loose.dx, reason: 'no indent for grouped dives');
    });

    testWidgets('compact mode groups too', (tester) async {
      final overrides = await groupingOverrides(
        [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
        viewMode: ListViewMode.compact,
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
    });

    testWidgets('tapping the header hides the trip dives', (tester) async {
      final overrides = await groupingOverrides(
        [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Site d1'), findsOneWidget);

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(find.text('Site d1'), findsNothing);
      expect(
        find.byType(TripGroupHeader),
        findsOneWidget,
        reason: 'a collapsed trip keeps its header so it stays findable',
      );
    });

    testWidgets('no headers when grouping is off', (tester) async {
      final overrides = await groupingOverrides(
        [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
        grouping: false,
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsNothing);
      expect(find.text('Site d1'), findsOneWidget);
    });

    testWidgets('a collapsed trip auto-expands when it holds the open dive', (
      tester,
    ) async {
      // The list must never fold away the dive the diver is looking at, even
      // when that dive's trip is in the collapsed set.
      final overrides = await groupingOverrides(
        [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();
      expect(find.text('Site d1'), findsNothing);

      // Re-pump with that dive selected, as the master-detail pane would.
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false, selectedId: 'd1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Site d1'),
        findsOneWidget,
        reason: 'the open dive forces its trip back open',
      );
    });

    testWidgets('the open-trip button navigates to the trip', (tester) async {
      final overrides = await groupingOverrides(
        [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
        tripTotals: const {'t1': 1},
      );

      String? visited;
      final router = GoRouter(
        initialLocation: '/dives',
        routes: [
          GoRoute(
            path: '/dives',
            builder: (_, _) =>
                const Scaffold(body: DiveListContent(showAppBar: false)),
          ),
          GoRoute(
            path: '/trips/:id',
            builder: (_, state) {
              visited = state.pathParameters['id'];
              return const Scaffold(body: Text('trip page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();

      expect(visited, 't1');
      expect(find.text('trip page'), findsOneWidget);
    });

    testWidgets('a fully collapsed page still asks for the next one', (
      tester,
    ) async {
      final dives = [
        for (var i = 0; i < 8; i++)
          makeDive('d$i', tripId: 't1', tripName: 'Tassie'),
      ];
      final notifier = MockPaginatedNotifier(dives, hasMore: true)
        ..pagesRemaining = 2
        // Every further page lands inside the same collapsed trip, so nothing
        // new becomes visible and only the sentinel can drive the paging.
        ..nextPageBuilder = (page) => [
          for (var i = 0; i < 8; i++)
            makeDive('d${page * 100 + i}', tripId: 't1', tripName: 'Tassie'),
        ];
      final overrides = await groupingOverrides(
        dives,
        tripTotals: const {'t1': 40},
        notifier: notifier,
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(
        notifier.loadNextPageCalls,
        greaterThanOrEqualTo(2),
        reason:
            'the sentinel must keep paging while every dive is hidden, until '
            'the source reports exhaustion',
      );
      expect(
        notifier.pagesRemaining,
        0,
        reason: 'it drained the source rather than stalling part way',
      );
      expect(
        notifier.loadNextPageCalls,
        lessThan(20),
        reason: 'and stopped once hasMore went false, rather than spinning',
      );
    });
  });
}
