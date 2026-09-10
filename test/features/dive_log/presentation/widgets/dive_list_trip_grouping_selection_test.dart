import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart'
    show DiveListTile;
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

void main() {
  Finder headerCheckbox() => find.descendant(
    of: find.byType(TripGroupHeader),
    matching: find.byType(Checkbox),
  );

  Finder tileFinder(String id) =>
      find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

  Future<void> pumpList(WidgetTester tester) async {
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
  }

  group('trip group selection', () {
    testWidgets('no group checkbox outside selection mode', (tester) async {
      await pumpList(tester);

      expect(headerCheckbox(), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('the group checkbox selects every loaded dive in the trip', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      expect(headerCheckbox(), findsOneWidget);
      expect(
        tester.widget<Checkbox>(headerCheckbox()).value,
        isFalse,
        reason: 'nothing in the group is selected yet',
      );

      await tester.tap(headerCheckbox());
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(headerCheckbox()).value,
        isTrue,
        reason: 'every loaded dive in the trip is now selected',
      );
    });

    testWidgets('checking one of two dives leaves the group mixed', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(tileFinder('d2'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(headerCheckbox()).value,
        isNull,
        reason: 'a partly selected group reads as mixed',
      );
    });

    testWidgets('unchecking a full group clears only that group', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // Select the loose dive as well, so the clear has something to spare.
      await tester.tap(tileFinder('d1'));
      await tester.pumpAndSettle();
      await tester.tap(headerCheckbox());
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(headerCheckbox()).value, isTrue);

      await tester.tap(headerCheckbox());
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(headerCheckbox()).value,
        isFalse,
        reason: 'the group cleared',
      );
      expect(
        tester.widget<DiveListTile>(tileFinder('d1')).isChecked,
        isTrue,
        reason: 'the loose dive outside the group kept its selection',
      );
    });

    testWidgets('collapsing a group does not clear its selection', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(headerCheckbox());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(headerCheckbox()).value,
        isTrue,
        reason: 'folding a trip away must not deselect its dives',
      );
    });
  });
}
