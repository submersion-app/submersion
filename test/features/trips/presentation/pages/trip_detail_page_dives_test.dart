import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// The Dives card's Scan for dives is held in the trip's sitting behind
/// the phase 3 switch (issue #4527): its dives wait for Save, and one it
/// added can be taken out first.
void main() {
  final l = AppLocalizationsEn();

  final candidates = [
    DiveCandidate(
      dive: Dive(id: 'v1', dateTime: DateTime(2030, 6, 2, 9)),
    ),
  ];

  Future<TripPageHarness> pumpWithDiver(WidgetTester tester) async {
    final harness = await pumpTripPage(
      tester,
      candidates: candidates,
      activeDiverId: 'd1',
      // Wide enough that the tab row shows the Dives tab.
      size: const Size(1000, 1600),
    );
    await ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(currentDiverIdProvider.notifier).setCurrentDiver('d1');
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> showDives(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_dives));
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester, {bool choose = true}) async {
    await tester.tap(find.byKey(const Key('trip-dives-scan')));
    await tester.pumpAndSettle();
    if (choose) await tapText(tester, l.trips_diveScan_addButton(1));
  }

  testWidgets('locked, Scan for dives unlocks the page, and the dives it '
      'chose wait for Save, then are assigned in one entry', (tester) async {
    final harness = await pumpWithDiver(tester);
    await showDives(tester);

    await scan(tester);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byKey(const Key('trip-dive-v1')), findsOneWidget);
    expect(find.text(l.trips_sitting_notSaved), findsOneWidget);
    expect(harness.tripDives.assigned, isEmpty);

    await tapText(tester, l.forms_save);

    expect(harness.save.calls.single.cards, {'dives'});
    expect(harness.tripDives.assigned, [
      ['v1'],
    ]);
  });

  testWidgets('a dive taken out is not assigned', (tester) async {
    final harness = await pumpWithDiver(tester);
    await showDives(tester);
    await scan(tester);

    await tester.tap(find.byKey(const Key('trip-dive-takeOut-v1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-dive-v1')), findsNothing);
    await tapText(tester, l.common_action_cancel);
    expect(harness.tripDives.assigned, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('the scan leaves out dives the sitting holds already', (
    tester,
  ) async {
    await pumpWithDiver(tester);
    await showDives(tester);
    await scan(tester);

    await scan(tester, choose: false);

    expect(find.text(l.trips_diveScan_noMatches), findsOneWidget);
  });

  testWidgets('dates changed after a scan ask nothing about the dives the '
      'scan holds, and assign them once', (tester) async {
    final harness = await pumpWithDiver(tester);
    await showDives(tester);
    await scan(tester);
    RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(TabBar)),
    )!.session!.set(tripDatesField, (
      start: DateTime(2030, 5, 30),
      end: DateTime(2030, 6, 8),
    ));
    await tester.pumpAndSettle();

    await tapText(tester, l.forms_save);

    expect(find.text(l.trips_diveScan_addButton(1)), findsNothing);
    expect(harness.tripDives.assigned, [
      ['v1'],
    ]);
    expect(harness.save.calls.single.cards, {'header', 'dives'});
  });
}
