import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show makeDive;

typedef _Pending = ({Completer<bool> done, int targetIndex});

/// A list whose far loads wait until the test settles them.
class _HeldNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _HeldNotifier(this.all)
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
  final calls = <(String, int)>[];
  final pending = <_Pending>[];
  bool fail = false;

  @override
  Future<bool> loadThrough(String diveId, {required int targetIndex}) {
    calls.add((diveId, targetIndex));
    if (fail) return Future.error(StateError('load failed'));
    final done = Completer<bool>();
    pending.add((done: done, targetIndex: targetIndex));
    return done.future;
  }

  void settleLoad(int i) {
    final load = pending[i];
    final through = (load.targetIndex + 51).clamp(0, all.length);
    state = AsyncValue.data(
      state.value!.copyWith(
        dives: all.take(through).toList(),
        hasMore: through < all.length,
      ),
    );
    load.done.complete(true);
  }

  /// Re-reads the same rows, as a sync write's silent reload does.
  void reloadInPlace() {
    state = AsyncValue.data(
      state.value!.copyWith(revision: state.value!.revision + 1),
    );
  }

  /// Swaps in the rows of another query, as a filter change does.
  void replaceRows(List<DiveSummary> rows) {
    state = AsyncValue.data(
      PaginatedDiveListState(
        dives: rows.take(50).toList(),
        totalCount: rows.length,
        revision: state.value!.revision + 1,
      ),
    );
  }

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  List<DiveSummary> dives(String prefix, int count) => [
    for (var i = 0; i < count; i++) makeDive('d$i').copyWith(id: '$prefix$i'),
  ];

  List<DiveScrubberEntry> indexOf(List<DiveSummary> rows) => [
    for (final d in rows)
      DiveScrubberEntry(
        id: d.id,
        sortTimestamp: d.sortTimestamp,
        diveNumber: d.diveNumber,
        siteName: d.siteName,
      ),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_HeldNotifier> pumpList(
    WidgetTester tester, {
    required List<DiveSummary> rows,
    FutureOr<List<DiveScrubberEntry>> Function(int? revision)? index,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final notifier = _HeldNotifier(rows);
    final base = await getBaseOverrides();
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          diveListGroupTripsProvider.overrideWith((ref) => false),
          tripDiveCountsProvider.overrideWith(
            (ref) async => const <String, int>{},
          ),
          collapsedTripIdsProvider.overrideWith(
            (ref) => CollapsedTripsNotifier(prefs, null),
          ),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
          diveScrubberIndexProvider.overrideWith((ref) {
            final revision = ref.watch(
              paginatedDiveListProvider.select((s) => s.valueOrNull?.revision),
            );
            DiveScrubberIndex built(List<DiveScrubberEntry> entries) =>
                DiveScrubberIndex(
                  entries: entries,
                  diverId: ref.read(currentDiverIdProvider),
                  filter: ref.read(diveFilterProvider),
                  sort: ref.read(diveSortProvider),
                );
            final entries = index?.call(revision) ?? indexOf(rows);
            return entries is Future<List<DiveScrubberEntry>>
                ? entries.then(built)
                : built(entries);
          }),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await settle(tester);
    return notifier;
  }

  Finder row(String id) => find.byWidgetPredicate(
    (w) => w is KeyboardListItem && w.navigationKey == id,
  );

  ListScrubber scrubber(WidgetTester tester) =>
      tester.widget<ListScrubber>(find.byType(ListScrubber));

  Future<void> showThumb(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
    await tester.pump();
  }

  /// Drags the thumb to [slot] of [slotCount] and holds it there.
  Future<TestGesture> holdOn(
    WidgetTester tester,
    int slot,
    int slotCount,
  ) async {
    final list = tester.getRect(find.byType(CustomScrollView));
    final thumbY = tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy;
    final target = trackForSlot(
      slot: slot,
      trackExtent: list.height - 48,
      slotCount: slotCount,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(Offset(0, list.top + target - thumbY));
    await tester.pump();
    return gesture;
  }

  /// Drags the thumb to [slot] of [slotCount] and lets go.
  Future<void> dropOn(WidgetTester tester, int slot, int slotCount) async {
    final gesture = await holdOn(tester, slot, slotCount);
    await gesture.up();
    await tester.pump();
  }

  double scrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  bool scrubbing(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiveListContent)),
  ).read(diveListScrubbingProvider);

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiveListContent)));

  group('a stale index', () {
    testWidgets('a filter change never uses the old index', (tester) async {
      final old = dives('d', 300);
      final fresh = dives('n', 200);
      final refetch = Completer<List<DiveScrubberEntry>>();
      final notifier = await pumpList(
        tester,
        rows: old,
        index: (revision) => revision == 1 ? indexOf(old) : refetch.future,
      );
      expect(scrubber(tester).slotCount, 300);

      container(tester).read(diveFilterProvider.notifier).state =
          const DiveFilterState(minDepth: 20);
      await tester.pump();
      expect(scrubber(tester).slotCount, 0);

      notifier.replaceRows(fresh);
      await tester.pump();
      expect(scrubber(tester).slotCount, 0);
      expect(scrubber(tester).markers, isEmpty);
      await showThumb(tester);
      expect(find.byKey(ListScrubber.thumbKey), findsNothing);

      refetch.complete(indexOf(fresh));
      await settle(tester);
      expect(scrubber(tester).slotCount, 200);

      await showThumb(tester);
      await dropOn(tester, 199, 200);
      expect(notifier.calls, [('n199', 199)]);
    });

    testWidgets('a sort change never uses the old index', (tester) async {
      final old = dives('d', 300);
      final resorted = old.reversed.toList();
      final notifier = await pumpList(
        tester,
        rows: old,
        index: (revision) => indexOf(revision == 1 ? old : resorted),
      );
      expect(scrubber(tester).slotCount, 300);

      container(tester).read(diveSortProvider.notifier).state = const SortState(
        field: DiveSortField.depth,
        direction: SortDirection.descending,
      );
      await tester.pump();
      expect(scrubber(tester).slotCount, 0);

      notifier.replaceRows(resorted);
      await settle(tester);
      expect(scrubber(tester).slotCount, 300);
      await showThumb(tester);
      await dropOn(tester, 299, 300);
      expect(notifier.calls, [('d0', 299)]);
    });

    testWidgets('a reload for the same query keeps the index and the drag', (
      tester,
    ) async {
      final rows = dives('d', 300);
      final refetch = Completer<List<DiveScrubberEntry>>();
      final notifier = await pumpList(
        tester,
        rows: rows,
        index: (revision) => revision == 1 ? indexOf(rows) : refetch.future,
      );
      await showThumb(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ListScrubber.thumbKey)),
      );
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);

      notifier.reloadInPlace();
      await tester.pump();
      expect(scrubber(tester).slotCount, 300);
      expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);

      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(notifier.calls, hasLength(1));
      expect(notifier.calls.single.$1, startsWith('d'));
      expect(scrubber(tester).slotCount, 300);

      refetch.complete(indexOf(rows));
      await settle(tester);
    });
  });

  // The drag already scrolls the list through loaded rows, so letting go
  // there must not move it again (#3574).
  group('a drop on a loaded row', () {
    testWidgets('leaves the list where the drag put it', (tester) async {
      final notifier = await pumpList(tester, rows: dives('d', 300));
      await showThumb(tester);
      final gesture = await holdOn(tester, 25, 300);
      final dragged = scrollOffset(tester);
      expect(dragged, greaterThan(0));
      final list = tester.getRect(find.byType(CustomScrollView));
      final held = tester.getRect(row('d25'));
      expect(held.top, greaterThan(list.top + held.height));

      await gesture.up();
      await settle(tester);

      expect(notifier.calls, isEmpty);
      expect(scrollOffset(tester), dragged);
      expect(tester.getRect(row('d25')), held);
    });

    testWidgets('cancels the landing of an earlier far drop', (tester) async {
      final notifier = await pumpList(tester, rows: dives('d', 300));
      await showThumb(tester);
      await dropOn(tester, 150, 300);
      expect(scrubber(tester).busyLabel, isNotNull);

      await dropOn(tester, 25, 300);
      await tester.pump();
      expect(scrubber(tester).busyLabel, isNull);
      final dropped = scrollOffset(tester);

      notifier.settleLoad(0);
      await settle(tester);
      expect(notifier.calls, [('d150', 150)]);
      expect(scrubber(tester).busyLabel, isNull);
      expect(scrollOffset(tester), dropped);
    });
  });

  group('overlapping drops', () {
    testWidgets('only the latest drop clears the busy state and lands', (
      tester,
    ) async {
      final notifier = await pumpList(tester, rows: dives('d', 300));
      await showThumb(tester);
      await dropOn(tester, 150, 300);
      await tester.pump();
      expect(scrubber(tester).busyLabel, isNotNull);

      await dropOn(tester, 250, 300);
      await tester.pump();
      expect(notifier.calls.map((c) => c.$1), ['d150', 'd250']);

      notifier.settleLoad(0);
      await settle(tester);
      expect(scrubber(tester).busyLabel, isNotNull);
      expect(scrubbing(tester), isTrue);
      final list = tester.getRect(find.byType(CustomScrollView));
      final early = row('d150');
      if (early.evaluate().isNotEmpty) {
        expect(tester.getRect(early).top, isNot(closeTo(list.top, 4)));
      }

      notifier.settleLoad(1);
      await settle(tester);
      expect(scrubber(tester).busyLabel, isNull);
      expect(tester.getRect(row('d250')).top, closeTo(list.top, 4));
    });

    testWidgets('a failed load clears the busy state and the scrubbing flag', (
      tester,
    ) async {
      final notifier = await pumpList(tester, rows: dives('d', 300))
        ..fail = true;
      await showThumb(tester);
      await dropOn(tester, 150, 300);
      await settle(tester);

      expect(notifier.calls, [('d150', 150)]);
      expect(scrubber(tester).busyLabel, isNull);
      await tester.pump(ListScrubber.idleHide);
      await settle(tester);
      expect(scrubbing(tester), isFalse);
    });
  });
}
