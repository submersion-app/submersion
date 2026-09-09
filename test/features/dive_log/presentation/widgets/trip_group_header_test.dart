import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_list_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  TripSection section({
    int loaded = 2,
    int total = 2,
    bool collapsed = false,
    String name = 'Tassie',
  }) {
    return TripSection(
      tripId: 't1',
      tripName: name,
      startDate: DateTime(2026, 6, 8),
      endDate: DateTime(2026, 6, 9),
      entries: [
        for (var i = 0; i < loaded; i++)
          DiveListEntry(
            dive: DiveSummary(
              id: 'd$i',
              dateTime: DateTime(2026, 6, 8),
              sortTimestamp: 0,
              tripId: 't1',
              tripName: name,
            ),
            flatIndex: i,
          ),
      ],
      collapsed: collapsed,
      totalCount: total,
    );
  }

  Future<void> pumpHeader(
    WidgetTester tester, {
    required TripSection value,
    VoidCallback? onToggle,
    VoidCallback? onOpenTrip,
    bool isSelectionMode = false,
    bool? groupChecked,
    ValueChanged<bool?>? onGroupCheckedChanged,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: TripGroupHeader(
          section: value,
          onToggle: onToggle ?? () {},
          onOpenTrip: onOpenTrip ?? () {},
          isSelectionMode: isSelectionMode,
          groupChecked: groupChecked,
          onGroupCheckedChanged: onGroupCheckedChanged,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TripGroupHeader', () {
    testWidgets('shows the trip name', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.text('Tassie'), findsOneWidget);
    });

    testWidgets('shows a plain count when the whole trip is loaded', (
      tester,
    ) async {
      await pumpHeader(tester, value: section(loaded: 4, total: 4));

      expect(find.textContaining('4 dives'), findsOneWidget);
      expect(find.textContaining(' of '), findsNothing);
    });

    testWidgets('shows "6 of 14 dives" when only part of the trip is loaded', (
      tester,
    ) async {
      await pumpHeader(tester, value: section(loaded: 6, total: 14));

      expect(find.textContaining('6 of 14 dives'), findsOneWidget);
    });

    testWidgets('shows the trip date range', (tester) async {
      await pumpHeader(tester, value: section());

      expect(find.textContaining('Jun'), findsOneWidget);
    });

    testWidgets('tapping anywhere on the header toggles', (tester) async {
      var toggled = 0;
      await pumpHeader(tester, value: section(), onToggle: () => toggled++);

      await tester.tap(find.byType(TripGroupHeader));
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });

    testWidgets('the chevron points down when expanded', (tester) async {
      await pumpHeader(tester, value: section());
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('the chevron points right when collapsed', (tester) async {
      await pumpHeader(tester, value: section(collapsed: true));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('the open-trip button fires its own callback', (tester) async {
      var opened = 0;
      var toggled = 0;
      await pumpHeader(
        tester,
        value: section(),
        onToggle: () => toggled++,
        onOpenTrip: () => opened++,
      );

      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(toggled, 0, reason: 'opening a trip must not also fold it');
    });

    testWidgets('selection mode swaps the open button for a checkbox', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        value: section(),
        isSelectionMode: true,
        groupChecked: false,
        onGroupCheckedChanged: (_) {},
      );

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('a partly selected group reads as mixed', (tester) async {
      await pumpHeader(
        tester,
        value: section(),
        isSelectionMode: true,
        groupChecked: null,
        onGroupCheckedChanged: (_) {},
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
    });
  });
}
