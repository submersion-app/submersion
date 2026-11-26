import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/test_app.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';

DiveSummary _summary(String id, DateTime dateTime) =>
    DiveSummary(id: id, dateTime: dateTime, sortTimestamp: 0);

/// Serves the first [pageSize] of [all] and holds the rest back until
/// [loadRest], the way the real list holds every dive past its first page
/// until the diver scrolls or asks for them (issue #5022).
class _PagedNotifier extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _PagedNotifier(this.all, {required int pageSize})
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: all.take(pageSize).toList(),
            hasMore: all.length > pageSize,
            totalCount: all.length,
          ),
        ),
      );

  final List<DiveSummary> all;
  int restLoads = 0;

  @override
  Future<void> loadRest() async {
    restLoads++;
    state = AsyncValue.data(
      state.requireValue.copyWith(dives: all, hasMore: false),
    );
  }

  // A short first page leaves the list stranded, which asks for the next one;
  // only loadRest brings the held-back rows in, so each test controls when.
  @override
  Future<void> loadNextPage() async {}

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps a second of frames. pumpAndSettle never returns here: a list with
/// dives past its loaded page shows the trailing spinner until they load.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// [enterSelectionViaMenu], settled with [_settle].
Future<void> _enterSelection(WidgetTester tester) async {
  await tester.tap(overflowMenuButton);
  await _settle(tester);
  await tester.tap(find.byKey(selectItemsMenuKey));
  await _settle(tester);
}

void main() {
  final selectAll = find.byKey(const ValueKey('selection_select_all'));

  final dives = [
    _summary('d1', DateTime(2026, 3, 3)),
    _summary('d2', DateTime(2026, 3, 2)),
    _summary('d3', DateTime(2026, 3, 1)),
  ];

  Future<_PagedNotifier> pumpList(WidgetTester tester) async {
    final notifier = _PagedNotifier(dives, pageSize: 2);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          paginatedDiveListProvider.overrideWith((ref) => notifier),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await _settle(tester);
    return notifier;
  }

  testWidgets('Select All checks the dives past the loaded page', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    await _enterSelection(tester);

    await tester.tap(selectAll);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('Select All stays on while dives past the page are unchecked', (
    tester,
  ) async {
    await pumpList(tester);
    await _enterSelection(tester);

    // Every loaded dive checked by hand is not every dive the filter matches.
    for (final id in ['d1', 'd2']) {
      await tester.tap(
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id),
      );
      await _settle(tester);
    }
    expect(find.text('2 selected'), findsOneWidget);
    expect(tester.widget<IconButton>(selectAll).onPressed, isNotNull);
  });

  testWidgets('Ctrl-A checks the dives past the loaded page', (tester) async {
    final notifier = await pumpList(tester);
    await _enterSelection(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('Select by date range reaches dives past the loaded page', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    await _enterSelection(tester);

    // In the overflow at the pane bar's one inline slot.
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('selection_menu_date_range')));
    await _settle(tester);

    // Typed rather than tapped on the calendar, which opens on today.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await _settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '03/01/2026');
    await tester.enterText(fields.at(1), '03/02/2026');
    await tester.tap(find.text('OK'));
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('2 selected'), findsOneWidget);
  });
}
