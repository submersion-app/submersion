import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';
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

  /// Makes [loadRest] end with the list reloading from the top, as a filter
  /// or sort change queued behind it does.
  bool reloadAfterRest = false;

  /// Makes [loadRest] fail its read, as the real notifier does: the loaded
  /// rows stay and the list is flagged for retry.
  bool failRest = false;

  @override
  Future<void> loadRest() async {
    restLoads++;
    if (failRest) {
      state = AsyncValue.data(
        state.requireValue.copyWith(loadMoreFailed: true),
      );
      return;
    }
    state = reloadAfterRest
        ? const AsyncValue.loading()
        : AsyncValue.data(
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
        // Pinned: these assertions read English labels and type dates in
        // the English date picker's format.
        locale: const Locale('en'),
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

  testWidgets('Select All keeps the checks when the list reloads meanwhile', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    notifier.reloadAfterRest = true;
    await _enterSelection(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == 'd1'),
    );
    await _settle(tester);

    await tester.tap(selectAll);
    await tester.pump();

    // The dives on screen when Select All was tapped, not none.
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('Select All checks nothing and says so when a read fails', (
    tester,
  ) async {
    final notifier = await pumpList(tester);
    notifier.failRest = true;
    await _enterSelection(tester);

    await tester.tap(selectAll);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('0 selected'), findsOneWidget);
    expect(
      find.text(
        'Could not load every item, so Select all was not applied. '
        'Try again.',
      ),
      findsOneWidget,
    );
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

  // The last trip on screen can go on past the loaded page: its header
  // checkbox checked only the dives of it that were loaded.
  testWidgets('a trip header checks its dives past the loaded page', (
    tester,
  ) async {
    final notifier = await _pumpTripList(tester, lastDiveOnTrip: true);
    await _enterSelection(tester);

    await tester.tap(_tripHeaderCheckbox);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('a trip header loads the rest before trip counts arrive', (
    tester,
  ) async {
    final notifier = await _pumpTripList(
      tester,
      lastDiveOnTrip: true,
      countsPending: true,
    );
    await _enterSelection(tester);

    await tester.tap(_tripHeaderCheckbox);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('a cut-off trip with its loaded dives checked reads mixed', (
    tester,
  ) async {
    final notifier = await _pumpTripList(tester, lastDiveOnTrip: true);
    await _enterSelection(tester);
    for (final id in ['d2', 'd3']) {
      await tester.tap(
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id),
      );
      await _settle(tester);
    }

    expect(tester.widget<Checkbox>(_tripHeaderCheckbox).value, isNull);

    // A tap reaches the dive past the page instead of clearing the two.
    await tester.tap(_tripHeaderCheckbox);
    await _settle(tester);

    expect(notifier.restLoads, 1);
    expect(find.text('3 selected'), findsOneWidget);
    expect(tester.widget<Checkbox>(_tripHeaderCheckbox).value, isTrue);
  });

  testWidgets('a trip shown whole checks without loading the rest', (
    tester,
  ) async {
    final notifier = await _pumpTripList(tester, lastDiveOnTrip: false);
    await _enterSelection(tester);

    await tester.tap(_tripHeaderCheckbox);
    await _settle(tester);

    expect(notifier.restLoads, 0);
    expect(find.text('2 selected'), findsOneWidget);
  });
}

final _tripHeaderCheckbox = find.descendant(
  of: find.byType(TripGroupHeader),
  matching: find.byType(Checkbox),
);

/// A loose dive, then trip t1's dives d2 and d3 on page one, with d4 held
/// back. [lastDiveOnTrip] puts d4 on the trip, which then goes on past the
/// page; otherwise d4 is a loose dive and the trip is whole on screen.
/// [countsPending] holds the trips' dive counts back, as on a list just
/// opened.
Future<_PagedNotifier> _pumpTripList(
  WidgetTester tester, {
  required bool lastDiveOnTrip,
  bool countsPending = false,
}) async {
  DiveSummary tripDive(String id, int day) => DiveSummary(
    id: id,
    dateTime: DateTime(2026, 6, day),
    sortTimestamp: 0,
    tripId: 't1',
    tripName: 'Tassie',
    tripStartDate: DateTime(2026, 6, 1),
    tripEndDate: DateTime(2026, 6, 9),
  );
  final notifier = _PagedNotifier([
    _summary('d1', DateTime(2026, 7, 1)),
    tripDive('d2', 9),
    tripDive('d3', 8),
    if (lastDiveOnTrip)
      tripDive('d4', 7)
    else
      _summary('d4', DateTime(2026, 5, 1)),
  ], pageSize: 3);
  final base = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(
      const AppSettings(
        diveListViewMode: ListViewMode.detailed,
        groupTripsInDiveList: true,
      ),
    ),
  );
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...base,
        tripDiveCountsProvider.overrideWith(
          (ref) => countsPending
              ? Completer<Map<String, int>>().future
              : Future.value({'t1': lastDiveOnTrip ? 3 : 2}),
        ),
        paginatedDiveListProvider.overrideWith((ref) => notifier),
      ],
      child: const DiveListContent(showAppBar: false),
    ),
  );
  await _settle(tester);
  return notifier;
}
