import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Serves [_all] 50 rows at a time, as the real paged list does.
class _PagingNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _PagingNotifier(this._all, {int loaded = 50})
    : super(AsyncData(_page(_all, loaded)));

  /// Starts with nothing loaded, as a cold or reset list does.
  _PagingNotifier.loading(this._all) : super(const AsyncLoading());

  void finishFirstPage() => state = AsyncData(_page(_all, 50));

  final List<DiveSummary> _all;
  int loadNextPageCalls = 0;

  static PaginatedDiveListState _page(List<DiveSummary> all, int count) {
    final dives = all.sublist(0, count.clamp(0, all.length));
    return PaginatedDiveListState(
      dives: dives,
      hasMore: dives.length < all.length,
      totalCount: all.length,
    );
  }

  @override
  Future<void> loadNextPage() async {
    loadNextPageCalls++;
    state = AsyncData(_page(_all, state.value!.dives.length + 50));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveSummary> _summaries(int count) => [
  for (var i = 0; i < count; i++)
    DiveSummary(
      id: 'd$i',
      diveNumber: count - i,
      dateTime: DateTime(2024, 1, 1).subtract(Duration(days: i)),
      sortTimestamp: DateTime(
        2024,
        1,
        1,
      ).subtract(Duration(days: i)).millisecondsSinceEpoch,
    ),
];

Finder _row(String id) =>
    find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

Future<List<Override>> _overrides(
  _PagingNotifier list, {
  required String? highlighted,
}) async => [
  ...await getBaseOverrides(),
  diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  highlightedDiveIdProvider.overrideWith((ref) => highlighted),
  paginatedDiveListProvider.overrideWith((ref) => list),
];

/// A dive list built again after the diver left it (another section, then
/// back) comes back to the dive they last opened (#3301).
void main() {
  testWidgets('returns to the highlighted dive', (tester) async {
    final list = _PagingNotifier(_summaries(100), loaded: 100);
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(list, highlighted: 'd80'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(_row('d80'), findsOneWidget);
    expect(_row('d0'), findsNothing);
  });

  testWidgets('pages forward to a dive beyond the loaded rows', (tester) async {
    final list = _PagingNotifier(_summaries(100));
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(list, highlighted: 'd80'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(list.loadNextPageCalls, greaterThanOrEqualTo(1));
    expect(_row('d80'), findsOneWidget);
  });

  testWidgets('pages forward more than one page to reach the dive', (
    tester,
  ) async {
    final list = _PagingNotifier(_summaries(200));
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(list, highlighted: 'd160'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(list.loadNextPageCalls, greaterThanOrEqualTo(3));
    expect(_row('d160'), findsOneWidget);
  });

  testWidgets('a list still loading when built comes back once it loads', (
    tester,
  ) async {
    final list = _PagingNotifier.loading(_summaries(100));
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(list, highlighted: 'd40'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pump();

    list.finishFirstPage();
    await tester.pumpAndSettle();

    expect(_row('d40'), findsOneWidget);
    expect(_row('d0'), findsNothing);
  });

  testWidgets('a dive the list does not hold leaves it at the top', (
    tester,
  ) async {
    final list = _PagingNotifier(_summaries(60), loaded: 60);
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(list, highlighted: 'gone'),
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(_row('d0'), findsOneWidget);
  });

  testWidgets('a pushed dive list does not restore', (tester) async {
    final list = _PagingNotifier(_summaries(100), loaded: 100);
    final router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        GoRoute(
          path: '/dives',
          builder: (_, _) =>
              const Scaffold(body: DiveListContent(showAppBar: false)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: await _overrides(list, highlighted: 'd80'),
      ),
    );
    router.push('/dives');
    await tester.pumpAndSettle();

    expect(_row('d0'), findsOneWidget);
    expect(_row('d80'), findsNothing);
  });
}
