import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

/// A long list where alternating runs of six dives belong to a trip, so the
/// scrollable carries a realistic amount of group chrome between rows.
List<DiveSummary> _mixedList({int count = 120}) {
  return [
    for (var i = 0; i < count; i++)
      if (((i ~/ 6).isEven))
        makeDive('d$i', tripId: 't${i ~/ 6}', tripName: 'Trip ${i ~/ 6}')
      else
        makeDive('d$i'),
  ];
}

Set<String> _tripIdsIn(List<DiveSummary> dives) =>
    dives.map((d) => d.tripId).whereType<String>().toSet();

void main() {
  /// The list aims to put the selected dive a third of the way down the
  /// viewport. The default test viewport is 600 tall, so that is y = 200.
  const intendedTop = 200.0;

  Future<void> pumpWithSelection(
    WidgetTester tester, {
    required String selectedId,
    bool collapseTrips = false,
  }) async {
    final dives = _mixedList();
    final tripIds = _tripIdsIn(dives);
    final base = await groupingOverrides(
      dives,
      tripTotals: {for (final t in tripIds) t: 6},
    );

    // getBaseOverrides seeds the mock prefs and hands that same instance to
    // sharedPreferencesProvider, so writing to it here is what the notifier
    // will read. The notifier is pinned to a null diver so the key is the
    // unsuffixed one regardless of what the base overrides pick.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      kCollapsedTripIdsPrefsKey,
      collapseTrips ? tripIds.toList() : const [],
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          collapsedTripIdsProvider.overrideWith(
            (ref) => CollapsedTripsNotifier(prefs, null),
          ),
        ],
        child: DiveListContent(showAppBar: false, selectedId: selectedId),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('scroll to the selected dive with trip groups', () {
    testWidgets('a dive far down a list of collapsed trips lands near the '
        'intended position', (tester) async {
      // The case the flat estimate gets badly wrong. Every trip is folded, so
      // half the loaded dives occupy no height at all, while the headers that
      // replaced them do. Dividing total height by the loaded dive count
      // therefore underestimates the row height and ignores the headers,
      // landing the target jammed against the top edge instead of a third
      // down (measured: y=26 with the old formula, y=254 with this one).
      await pumpWithSelection(tester, selectedId: 'd115', collapseTrips: true);

      final row = find.text('Site d115');
      expect(row, findsOneWidget, reason: 'the target row must be built');

      final top = tester.getRect(row).top;
      expect(
        (top - intendedTop).abs(),
        lessThan(120),
        reason:
            'the selected dive should land near a third down the viewport, '
            'not clipped to an edge (was $top)',
      );
    });

    testWidgets('a dive far down an expanded grouped list is in view', (
      tester,
    ) async {
      await pumpWithSelection(tester, selectedId: 'd115');

      final row = find.text('Site d115');
      expect(row, findsOneWidget);

      final top = tester.getRect(row).top;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(600));
    });

    testWidgets('a loose dive below several trips is scrolled into view', (
      tester,
    ) async {
      // d20 is loose, but four trip headers sit above it.
      await pumpWithSelection(tester, selectedId: 'd20');

      expect(find.text('Site d20'), findsOneWidget);
    });

    testWidgets('the group headers survive the programmatic scroll', (
      tester,
    ) async {
      await pumpWithSelection(tester, selectedId: 'd115');

      expect(find.byType(TripGroupHeader), findsWidgets);
    });
  });
}
