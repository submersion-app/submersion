import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

DiveSummary summary(String id, [DateTime? dt]) =>
    DiveSummary(id: id, dateTime: dt ?? DateTime(2026, 1, 1), sortTimestamp: 0);

Dive _makeDive({required String id, DiveSite? site, DateTime? dateTime}) {
  final dt = dateTime ?? DateTime(2026, 1, 1);
  return Dive(id: id, dateTime: dt, entryTime: dt, site: site);
}

/// Fake [DiveRepository] for the combine dialog's `getDivesByIds`.
class _FakeDiveRepository implements DiveRepository {
  _FakeDiveRepository(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesByIds(List<String> ids) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [DiveMergeService] whose `apply` returns a canned merged dive.
class _StubMergeService implements DiveMergeService {
  _StubMergeService(this.mergedDiveId);
  final String mergedDiveId;

  @override
  Future<DiveMergeOutcome> apply(List<String> diveIds) async =>
      DiveMergeOutcome(
        mergedDive: Dive(id: mergedDiveId, dateTime: DateTime(2026, 1, 1)),
        snapshot: DiveMergeSnapshot(
          mergedDiveId: mergedDiveId,
          diveRows: const [],
          profileRows: const [],
          tankRows: const [],
          weightRows: const [],
          customFieldRows: const [],
          equipmentRows: const [],
          diveTypeRows: const [],
          tagRows: const [],
          buddyRows: const [],
          sightingRows: const [],
          eventRows: const [],
          gasSwitchRows: const [],
          tankPressureRows: const [],
          dataSourceRows: const [],
          tideRows: const [],
          mediaDiveIds: const {},
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stand-in for [PaginatedDiveListNotifier] that serves a fixed list of
/// dives without touching the database. Mirrors the equivalent mock in
/// dive_list_content_test.dart.
class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives, {this.afterRefresh})
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  /// When set, [refresh] swaps the list to this -- simulating the DB reload
  /// after a combine picking up the newly created merged dive.
  final List<DiveSummary>? afterRefresh;

  @override
  Future<void> refresh() async {
    if (afterRefresh != null) {
      state = AsyncValue.data(
        PaginatedDiveListState(dives: afterRefresh!, hasMore: false),
      );
    }
  }

  // Scrolling to the bottom trips the list's load-more listener.
  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('rangeIds returns inclusive span regardless of direction', () {
    final dives = ['a', 'b', 'c', 'd'].map(summary).toList();
    expect(rangeIds(dives, 1, 3), ['b', 'c', 'd']);
    expect(rangeIds(dives, 3, 1), ['b', 'c', 'd']); // reversed
    expect(rangeIds(dives, 2, 2), ['c']); // single
  });

  test('inDateRange includes dives on the boundary days', () {
    final r = DateTimeRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 3),
    );
    expect(inDateRange(summary('a', DateTime(2026, 6, 1, 8)), r), isTrue);
    expect(inDateRange(summary('b', DateTime(2026, 6, 3, 23)), r), isTrue);
    expect(inDateRange(summary('c', DateTime(2026, 5, 31)), r), isFalse);
  });

  testWidgets('Combine action appears only with 2+ selected', (tester) async {
    final dives = [
      _makeDive(
        id: 'd1',
        site: const DiveSite(id: 's1', name: 'Aaa'),
      ),
      _makeDive(
        id: 'd2',
        site: const DiveSite(id: 's2', name: 'Bbb'),
      ),
    ];
    final summaries = dives.map(DiveSummary.fromDive).toList();
    final base = await getBaseOverrides();
    final overrides = [
      ...base,
      diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
      paginatedDiveListProvider.overrideWith(
        (ref) => _MockPaginatedNotifier(summaries),
      ),
    ];

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    Finder tileFinder(String id) =>
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

    // Long-press d1 -> enter selection mode with only d1 selected.
    await tester.longPress(tileFinder('d1'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Combine'), findsNothing);

    // Tap d2 -> two dives selected, Combine action appears.
    await tester.tap(tileFinder('d2'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Combine'), findsOneWidget);
  });

  testWidgets('successful combine selects the merged dive', (tester) async {
    final dives = [
      _makeDive(
        id: 'd1',
        site: const DiveSite(id: 's1', name: 'Aaa'),
        dateTime: DateTime(2026, 1, 1, 9),
      ),
      _makeDive(
        id: 'd2',
        site: const DiveSite(id: 's2', name: 'Bbb'),
        dateTime: DateTime(2026, 1, 1, 11),
      ),
    ];
    final summaries = dives.map(DiveSummary.fromDive).toList();
    final selections = <String?>[];
    final base = await getBaseOverrides();
    final overrides = [
      ...base,
      diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
      paginatedDiveListProvider.overrideWith(
        (ref) => _MockPaginatedNotifier(summaries),
      ),
      diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(dives)),
      diveMergeServiceProvider.overrideWithValue(_StubMergeService('merged-1')),
    ];

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: DiveListContent(
          showAppBar: false,
          onItemSelected: selections.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder tileFinder(String id) =>
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

    await tester.longPress(tileFinder('d1'));
    await tester.pumpAndSettle();
    await tester.tap(tileFinder('d2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Combine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combine into one dive'));
    await tester.pumpAndSettle();

    // The merged dive replaced the sources and becomes the list selection:
    // both the detail pane (onItemSelected) and the list-row highlight
    // (highlightedDiveIdProvider) must point at the merged dive.
    expect(selections, isNotEmpty);
    expect(selections.last, 'merged-1');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListContent)),
    );
    expect(container.read(highlightedDiveIdProvider), 'merged-1');
  });

  testWidgets('successful combine scrolls the merged dive into view', (
    tester,
  ) async {
    final sources = [
      _makeDive(id: 'd0', dateTime: DateTime(2026, 1, 1, 9)),
      _makeDive(id: 'd1', dateTime: DateTime(2026, 1, 1, 10)),
    ];
    final fillers = [
      for (var i = 0; i < 30; i++)
        _makeDive(id: 'f$i', dateTime: DateTime(2026, 1, 2, 0, i)),
    ];
    final merged = _makeDive(id: 'merged-1', dateTime: DateTime(2025, 1, 1));

    // Before combine the list shows the sources plus fillers (no merged dive).
    // After the reload it becomes the fillers plus the merged dive at the very
    // bottom -- off-screen until the list scrolls to it.
    final before = [...sources, ...fillers].map(DiveSummary.fromDive).toList();
    final after = [...fillers, merged].map(DiveSummary.fromDive).toList();

    final base = await getBaseOverrides();
    final overrides = [
      ...base,
      diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
      paginatedDiveListProvider.overrideWith(
        (ref) => _MockPaginatedNotifier(before, afterRefresh: after),
      ),
      diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(sources)),
      diveMergeServiceProvider.overrideWithValue(_StubMergeService('merged-1')),
    ];

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    Finder tileFinder(String id) =>
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

    // Merged dive not present / off-screen before the combine.
    expect(tileFinder('merged-1'), findsNothing);

    await tester.longPress(tileFinder('d0'));
    await tester.pumpAndSettle();
    await tester.tap(tileFinder('d1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Combine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combine into one dive'));
    await tester.pumpAndSettle();

    // The reloaded list scrolled the merged dive into view.
    expect(tileFinder('merged-1'), findsOneWidget);
  });
}
