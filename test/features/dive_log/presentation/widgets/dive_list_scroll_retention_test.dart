import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Stands in for [PaginatedDiveListNotifier] so a test can replay exactly what
/// a change tick does to the list state.
class _FakePaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _FakePaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  int loadNextPageCalls = 0;

  @override
  Future<void> loadNextPage() async => loadNextPageCalls++;

  /// Replay a silent reload that refreshes the loaded rows in place, which is
  /// what the notifier does after a dive is written (#1610).
  void reloadInPlace(List<DiveSummary> dives) {
    state = AsyncValue.data(
      PaginatedDiveListState(dives: dives, hasMore: false),
    );
  }

  /// Replay a reload that drops the loaded pages, leaving more to fetch.
  void shrinkToFirstPage(List<DiveSummary> dives) {
    state = AsyncValue.data(
      PaginatedDiveListState(dives: dives, hasMore: true),
    );
  }

  /// Replay a page load that failed, which the notifier now records rather
  /// than swallowing.
  void failLoadMore(List<DiveSummary> dives) {
    state = AsyncValue.data(
      PaginatedDiveListState(dives: dives, hasMore: true, loadMoreFailed: true),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveSummary _summary(int n) => DiveSummary(
  id: 'd$n',
  diveNumber: n,
  name: 'Dive $n',
  dateTime: DateTime(2024, 1, 1).add(Duration(days: n)),
  sortTimestamp: DateTime(
    2024,
    1,
    1,
  ).add(Duration(days: n)).millisecondsSinceEpoch,
);

void main() {
  testWidgets('an in-place reload keeps the scroll offset and shows no loading '
      'row', (tester) async {
    final summaries = [for (var i = 60; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable).last;
    await tester.drag(listFinder, const Offset(0, -400));
    await tester.pumpAndSettle();

    final offsetBefore = tester
        .state<ScrollableState>(listFinder)
        .position
        .pixels;
    expect(offsetBefore, greaterThan(0));

    // The diver saves an edit: the same rows come back, one of them changed.
    notifier.reloadInPlace([
      summaries.first.copyWith(name: 'Edited name'),
      ...summaries.skip(1),
    ]);
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(listFinder).position.pixels,
      moreOrLessEquals(offsetBefore, epsilon: 0.5),
      reason: 'refreshing the loaded rows must not move the list (#1610)',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'a fully loaded list must not sprout a trailing spinner row',
    );
  });

  testWidgets('a loader row stranded by a shrinking list loads the next page '
      'without a scroll gesture', (tester) async {
    final summaries = [for (var i = 110; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll well past where a single page of rows would end.
    final listFinder = find.byType(Scrollable).last;
    for (var i = 0; i < 12; i++) {
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    notifier.loadNextPageCalls = 0;

    // The list shrinks under the scroll position. Flutter clamps the offset
    // during layout without notifying scroll listeners, so nothing but the
    // loader row itself can ask for the next page (#1610).
    notifier.shrinkToFirstPage(summaries.take(50).toList());
    // A running CircularProgressIndicator never lets pumpAndSettle settle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      notifier.loadNextPageCalls,
      greaterThan(0),
      reason:
          'the trailing spinner must never be a dead end the diver has to '
          'scroll out of by hand (#1610)',
    );
  });

  testWidgets('a failed page load offers a retry instead of a spinner that '
      'never resolves', (tester) async {
    final summaries = [for (var i = 60; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    // The next page could not be fetched. hasMore stays true and the row count
    // never changes, so nothing else can ever kick another load: a spinner here
    // would spin on nothing (#1610).
    notifier.failLoadMore(summaries);
    await tester.pumpAndSettle();

    final retry = find.byKey(const ValueKey('load_more_retry'));
    await tester.scrollUntilVisible(retry, 200);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(retry, findsOneWidget);

    notifier.loadNextPageCalls = 0;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(
      notifier.loadNextPageCalls,
      1,
      reason: 'the retry affordance must actually ask for the page again',
    );
  });

  testWidgets('a second shrink to a row count already seen still loads', (
    tester,
  ) async {
    final summaries = [for (var i = 110; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable).last;
    for (var i = 0; i < 12; i++) {
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    Future<void> shrinkAndPump() async {
      notifier.shrinkToFirstPage(summaries.take(50).toList());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    notifier.loadNextPageCalls = 0;
    await shrinkAndPump();
    expect(notifier.loadNextPageCalls, greaterThan(0));

    // The pages come back, then the list shrinks to that same count again --
    // a bulk delete, or a narrower reload. The row is stranded exactly as
    // before, so remembering the count it was last kicked at would refuse the
    // one kick that is needed (#1610).
    notifier.reloadInPlace(summaries);
    await tester.pumpAndSettle();

    notifier.loadNextPageCalls = 0;
    await shrinkAndPump();
    expect(
      notifier.loadNextPageCalls,
      greaterThan(0),
      reason: 'the kick must not be suppressed by a row count seen before',
    );
  });

  testWidgets('scrolling at the bottom does not retry a failed page load', (
    tester,
  ) async {
    final summaries = [for (var i = 60; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    notifier.failLoadMore(summaries);
    await tester.pump();

    // Park at the bottom of the list, where the retry row is.
    final listFinder = find.byType(Scrollable).last;
    final retry = find.byKey(const ValueKey('load_more_retry'));
    await tester.scrollUntilVisible(retry, 200);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(listFinder).position.pixels,
      greaterThan(0),
    );

    // Jitter within the bottom 200px, which is what riding the end of the list
    // looks like: every one of these is a scroll notification inside the
    // threshold that would normally ask for the next page.
    notifier.loadNextPageCalls = 0;
    for (var i = 0; i < 4; i++) {
      await tester.drag(listFinder, const Offset(0, 60));
      await tester.pumpAndSettle();
      await tester.drag(listFinder, const Offset(0, -60));
      await tester.pumpAndSettle();
    }

    expect(
      notifier.loadNextPageCalls,
      0,
      reason:
          'scrolling must not bypass the Retry button and put a failing query '
          'behind every settle (#1610)',
    );

    // The button is still the way forward.
    notifier.loadNextPageCalls = 0;
    await tester.tap(retry);
    await tester.pump();
    expect(notifier.loadNextPageCalls, 1);
  });

  testWidgets('a kick scheduled before a load fails does not retry it', (
    tester,
  ) async {
    // Short enough that the loader row is on screen from the first frame, so
    // the kick is scheduled during that frame's layout.
    final summaries = [for (var i = 3; i >= 1; i--) _summary(i)];
    final notifier = _FakePaginatedNotifier(summaries)
      ..shrinkToFirstPage(summaries);
    final base = await getBaseOverrides();

    // Post-frame callbacks run in registration order, and a parent builds
    // before the child whose layout schedules the kick. So this lands first
    // and stands in for a page load that started and failed inside the same
    // frame the kick was scheduled in.
    var flipped = false;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (flipped) return;
              flipped = true;
              notifier.failLoadMore(summaries);
            });
            return const DiveListContent(showAppBar: true);
          },
        ),
      ),
    );
    await tester.pump();

    expect(flipped, isTrue, reason: 'the interleaving under test must happen');
    expect(
      notifier.loadNextPageCalls,
      0,
      reason:
          'a kick scheduled before the failure must re-read the state, not '
          'clear loadMoreFailed and retry behind the Retry button (#1610)',
    );
  });
}
