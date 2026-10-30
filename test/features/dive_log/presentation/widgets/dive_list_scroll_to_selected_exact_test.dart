import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show makeDive;
import 'dive_scrubber_index_override.dart';

/// Every row loaded, so the list can only miss by where it scrolls.
class _LoadedNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _LoadedNotifier(List<DiveSummary> all)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: all,
            totalCount: all.length,
            hasMore: false,
            revision: 1,
          ),
        ),
      );

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final tag = Tag(
    id: 'tag',
    name: 'Wreck',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  // Newest first. The newer half carries tags, so its rows stand taller
  // than the older half's: an offset averaged over the rows built at the
  // top overshoots a dive in the older half by a hundred rows' difference.
  final rows = [
    for (var n = 300; n >= 1; n--)
      n > 150 ? makeDive('d$n').copyWith(tags: [tag]) : makeDive('d$n'),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder row(String id) => find.byWidgetPredicate(
    (w) => w is KeyboardListItem && w.navigationKey == id,
  );

  /// Pumps the list with [selected] as its address's selection, which a
  /// test changes from outside the list, as the detail pane does.
  Future<void> pumpList(
    WidgetTester tester,
    ValueNotifier<String?> selected,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          diveListGroupTripsProvider.overrideWith((ref) => false),
          tripDiveCountsProvider.overrideWith(
            (ref) async => const <String, int>{},
          ),
          collapsedTripIdsProvider.overrideWith(
            (ref) => CollapsedTripsNotifier(prefs, null),
          ),
          paginatedDiveListProvider.overrideWith(
            (ref) => _LoadedNotifier(rows),
          ),
          diveScrubberIndexOverride(
            () => [
              for (final d in rows)
                DiveScrubberEntry(
                  id: d.id,
                  sortTimestamp: d.sortTimestamp,
                  diveNumber: d.diveNumber,
                  siteName: d.siteName,
                ),
            ],
          ),
        ],
        child: ValueListenableBuilder<String?>(
          valueListenable: selected,
          builder: (_, id, _) => DiveListContent(
            showAppBar: false,
            selectedId: id,
            onItemSelected: (_) {},
          ),
        ),
      ),
    );
    await settle(tester);
  }

  void expectInView(WidgetTester tester, String id) {
    expect(row(id), findsOneWidget);
    final list = tester.getRect(find.byType(CustomScrollView));
    final target = tester.getRect(row(id));
    expect(target.top, greaterThanOrEqualTo(list.top - 0.5));
    expect(target.bottom, lessThanOrEqualTo(list.bottom + 0.5));
  }

  testWidgets('a selection from outside the list shows its row (#3744)', (
    tester,
  ) async {
    final selected = ValueNotifier<String?>('d100');
    addTearDown(selected.dispose);
    await pumpList(tester, selected);

    // The row itself, whole and on screen, not one somewhere around it.
    expectInView(tester, 'd100');
  });

  testWidgets('a newer selection is not pulled back by the scroll it cut '
      'short', (tester) async {
    final selected = ValueNotifier<String?>('d100');
    addTearDown(selected.dispose);
    await pumpList(tester, selected);

    // Away from both, then to one dive and, mid-scroll, to another.
    selected.value = 'd300';
    await settle(tester);
    selected.value = 'd60';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    selected.value = 'd280';
    await settle(tester);

    expectInView(tester, 'd280');
  });
}
