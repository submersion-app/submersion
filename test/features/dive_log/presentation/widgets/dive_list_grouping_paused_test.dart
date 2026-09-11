import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    required DiveSortField sortField,
    bool grouping = true,
  }) async {
    final base = await groupingOverrides(
      [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
      grouping: grouping,
      tripTotals: const {'t1': 1},
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveSortProvider.overrideWith(
            (ref) => SortState(
              field: sortField,
              direction: SortDirection.descending,
            ),
          ),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('grouping paused by sort', () {
    testWidgets('a depth sort hides the headers and says why', (tester) async {
      await pumpList(tester, sortField: DiveSortField.depth);

      expect(find.byType(TripGroupHeader), findsNothing);
      expect(find.textContaining('Trip grouping is off'), findsOneWidget);
      expect(find.text('Sort by date'), findsOneWidget);
    });

    testWidgets('the notice names the offending sort', (tester) async {
      await pumpList(tester, sortField: DiveSortField.depth);

      expect(find.textContaining('Max Depth'), findsOneWidget);
    });

    testWidgets('the dives are still listed while grouping is paused', (
      tester,
    ) async {
      await pumpList(tester, sortField: DiveSortField.depth);

      expect(find.text('Site d1'), findsOneWidget);
    });

    testWidgets('no notice under a date sort', (tester) async {
      await pumpList(tester, sortField: DiveSortField.date);

      expect(find.textContaining('Trip grouping is off'), findsNothing);
      expect(find.byType(TripGroupHeader), findsOneWidget);
    });

    testWidgets('no notice when the toggle itself is off', (tester) async {
      await pumpList(tester, sortField: DiveSortField.depth, grouping: false);

      expect(find.textContaining('Trip grouping is off'), findsNothing);
    });

    testWidgets('the notice renders at exactly the height the scroll '
        'geometry assumes', (tester) async {
      // _scrollToSelectedItem subtracts kGroupingPausedNoticeHeight from the
      // scrollable to work out how much of it is dive rows, so the constant
      // has to match what this widget really renders at. It was 48 while the
      // widget rendered at 56, because the action button carries a 48px tap
      // target under 8px of padding, biasing every estimate by 8px whenever
      // the notice showed.
      //
      // The notice is deliberately left to size itself: constraining it to
      // the constant would make this assertion true by construction and prove
      // nothing.
      await pumpList(tester, sortField: DiveSortField.depth);

      expect(
        tester
            .getSize(find.byKey(const ValueKey('grouping_paused_notice')))
            .height,
        kGroupingPausedNoticeHeight,
        reason: 'the rendered notice and the scroll constant must agree',
      );
    });

    testWidgets('the action restores the date sort and the groups', (
      tester,
    ) async {
      await pumpList(tester, sortField: DiveSortField.depth);
      expect(find.byType(TripGroupHeader), findsNothing);

      await tester.tap(find.text('Sort by date'));
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
      expect(find.textContaining('Trip grouping is off'), findsNothing);
    });
  });
}
