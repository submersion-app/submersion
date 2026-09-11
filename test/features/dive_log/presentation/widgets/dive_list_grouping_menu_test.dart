import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    bool grouping = true,
    ListViewMode viewMode = ListViewMode.detailed,
  }) async {
    final overrides = await groupingOverrides(
      [makeDive('d1', tripId: 't1', tripName: 'Tassie')],
      grouping: grouping,
      tripTotals: const {'t1': 1},
      viewMode: viewMode,
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
  }

  group('dive list grouping menu', () {
    testWidgets('the overflow menu offers Group trips', (tester) async {
      await pumpList(tester);
      await openMenu(tester);

      expect(find.text('Group trips'), findsOneWidget);
    });

    testWidgets('expand and collapse all appear while grouping is active', (
      tester,
    ) async {
      await pumpList(tester);
      await openMenu(tester);

      expect(find.text('Expand all trips'), findsOneWidget);
      expect(find.text('Collapse all trips'), findsOneWidget);
    });

    testWidgets('expand and collapse all are hidden when grouping is off', (
      tester,
    ) async {
      await pumpList(tester, grouping: false);
      await openMenu(tester);

      expect(find.text('Group trips'), findsOneWidget);
      expect(find.text('Expand all trips'), findsNothing);
      expect(find.text('Collapse all trips'), findsNothing);
    });

    testWidgets('the grouping entries carry icons, not a checkbox', (
      tester,
    ) async {
      await pumpList(tester);
      await openMenu(tester);

      // Scoped to the menu entries: the trip glyph also appears on the group
      // header in the list behind the open menu.
      Finder iconIn(String label, IconData icon) => find.descendant(
        of: find.widgetWithText(PopupMenuItem<String>, label),
        matching: find.byIcon(icon),
      );

      expect(iconIn('Group trips', Icons.card_travel), findsOneWidget);
      expect(iconIn('Expand all trips', Icons.unfold_more), findsOneWidget);
      expect(iconIn('Collapse all trips', Icons.unfold_less), findsOneWidget);
      expect(
        find.byType(CheckedPopupMenuItem<String>),
        findsNothing,
        reason: 'the active state is a colour, not a checkbox',
      );
    });

    testWidgets('Group trips is tinted while grouping is on', (tester) async {
      await pumpList(tester);
      await openMenu(tester);

      final label = find.descendant(
        of: find.widgetWithText(PopupMenuItem<String>, 'Group trips'),
        matching: find.text('Group trips'),
      );
      final primary = Theme.of(tester.element(label)).colorScheme.primary;

      expect(
        tester.widget<Text>(label).style?.color,
        primary,
        reason: 'an active toggle reads as tinted, like the current view mode',
      );
    });

    testWidgets('Group trips is untinted while grouping is off', (
      tester,
    ) async {
      await pumpList(tester, grouping: false);
      await openMenu(tester);

      final label = find.descendant(
        of: find.widgetWithText(PopupMenuItem<String>, 'Group trips'),
        matching: find.text('Group trips'),
      );

      expect(
        tester.widget<Text>(label).style?.color,
        isNull,
        reason: 'an inactive toggle takes the default menu text colour',
      );
    });

    testWidgets('choosing Group trips turns grouping on', (tester) async {
      await pumpList(tester, grouping: false);
      expect(find.byType(TripGroupHeader), findsNothing);

      await openMenu(tester);
      await tester.tap(find.text('Group trips'));
      await tester.pumpAndSettle();

      expect(find.byType(TripGroupHeader), findsOneWidget);
    });

    testWidgets('Collapse all trips folds the visible trips', (tester) async {
      await pumpList(tester);
      expect(find.text('Site d1'), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.text('Collapse all trips'));
      await tester.pumpAndSettle();

      expect(find.text('Site d1'), findsNothing);
      expect(find.byType(TripGroupHeader), findsOneWidget);
    });

    testWidgets('Expand all trips opens them again', (tester) async {
      await pumpList(tester);

      await openMenu(tester);
      await tester.tap(find.text('Collapse all trips'));
      await tester.pumpAndSettle();
      expect(find.text('Site d1'), findsNothing);

      await openMenu(tester);
      await tester.tap(find.text('Expand all trips'));
      await tester.pumpAndSettle();

      expect(find.text('Site d1'), findsOneWidget);
    });
  });
}
