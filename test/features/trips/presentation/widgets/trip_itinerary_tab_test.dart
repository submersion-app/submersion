import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';

import 'trip_itinerary_tab_harness.dart';

/// The itinerary tab's day numbering, its loads, Generate and the day
/// edit sheet.
void main() {
  // #2664: rows written when the trip started on the 7th, and the start has
  // since moved a day earlier.
  final staleRows = [
    row('a', DateTime(2026, 3, 7), 1),
    row('b', DateTime(2026, 3, 9), 3),
  ];

  testWidgets('numbers days from the trip start, not the stored number', (
    tester,
  ) async {
    await pumpTab(tester, trip: trip(DateTime(2026, 3, 6)), days: staleRows);

    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Day 1'), findsNothing);
    expect(find.text('Day 3'), findsNothing);
  });

  testWidgets('the edit sheet names the renumbered day', (tester) async {
    await pumpTab(
      tester,
      trip: trip(DateTime(2026, 3, 6)),
      days: staleRows,
      inSitting: true,
    );

    await tester.tap(find.text('Day 4'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Day 4'), findsOneWidget);
  });

  testWidgets('renumbers the open tab when the trip start moves', (
    tester,
  ) async {
    await pumpTab(
      tester,
      trip: trip(DateTime(2026, 3, 7)),
      days: staleRows,
      // The trip as a later read sees it: the start moved a day earlier, as
      // a sync from another device would move it.
      tripAfter: trip(DateTime(2026, 3, 6)),
    );
    expect(find.text('Day 3'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(TripItineraryTab)),
    ).invalidate(tripByIdProvider('trip-1'));
    await tester.pumpAndSettle();

    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Day 3'), findsNothing);
  });

  testWidgets('keeps the list on screen while an edit reloads it', (
    tester,
  ) async {
    final pending = Completer<List<ItineraryDay>>();
    await pumpTab(
      tester,
      trip: trip(DateTime(2026, 3, 6)),
      days: staleRows,
      reload: pending.future,
    );

    // What a Save of the sitting, or a sync, does.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TripItineraryTab)),
    );
    container.invalidate(itineraryDaysProvider('trip-1'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Day 4'), findsOneWidget);
  });

  testWidgets('shows the stored numbers when the trip is gone', (tester) async {
    // Nothing to number from: the rows are listed as the repository returns
    // them (by date), under their stored numbers.
    await pumpTab(tester, trip: null, days: staleRows);

    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);
  });

  testWidgets('a failed itinerary load says so without the exception', (
    tester,
  ) async {
    await pumpTab(
      tester,
      trip: trip(DateTime(2026, 3, 6)),
      days: staleRows,
      loadError: StateError('database is locked'),
    );

    expect(find.text("Couldn't load the itinerary."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('with no sitting it offers no Generate and a tapped day opens '
      'no sheet', (tester) async {
    // Some dates have no row, so a sitting would offer Fill in missing days.
    await pumpTab(tester, trip: resortTrip(), days: staleRows);
    expect(find.byKey(const Key('trip-itinerary-generate')), findsNothing);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('an empty itinerary explains itself and offers Generate', (
    tester,
  ) async {
    await pumpTab(tester, trip: resortTrip(), days: const [], inSitting: true);
    expect(
      find.text('No itinerary yet. Generate one from the trip dates.'),
      findsOneWidget,
    );
    expect(find.text('Generate itinerary'), findsOneWidget);
    expect(find.text('No dives'), findsNothing);
  });

  testWidgets('a partial itinerary offers Fill in missing days above the '
      'list', (tester) async {
    await pumpTab(tester, trip: resortTrip(), days: staleRows, inSitting: true);
    expect(find.text('Fill in missing days'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('off a boat the sheet labels the place Location and offers '
      'land day types', (tester) async {
    await pumpTab(tester, trip: resortTrip(), days: staleRows, inSitting: true);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Port / Anchorage'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Travel').hitTestable(), findsOneWidget);
    expect(find.text('Rest').hitTestable(), findsOneWidget);
    expect(find.text('Embark').hitTestable(), findsNothing);
  });

  testWidgets('on a boat the sheet keeps Port / Anchorage and the maritime '
      'types', (tester) async {
    await pumpTab(
      tester,
      trip: trip(DateTime(2026, 3, 6)),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Port / Anchorage'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Embark').hitTestable(), findsOneWidget);
    expect(find.text('Travel').hitTestable(), findsOneWidget);
  });

  testWidgets('a sea day on a resort trip keeps its type', (tester) async {
    final sea = ItineraryDay(
      id: 'sea',
      tripId: 'trip-1',
      dayNumber: 2,
      date: DateTime(2026, 3, 7),
      dayType: DayType.seaDay,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: [sea],
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    // The dropdown shows the stored value even though a resort trip does
    // not offer it.
    expect(find.text('Sea Day'), findsWidgets);
    // A note, so the sheet hands back a changed day for Save to write.
    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(EditableText),
          )
          .at(1),
      'Crossing',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await savedDays(sitting!)).single;
    expect(saved.notes, 'Crossing');
    expect(saved.dayType, DayType.seaDay);
  });

  testWidgets(
    'the sheet saves planned dives, and a dive day at 0 keeps its type',
    (tester) async {
      final sitting = await pumpTab(
        tester,
        trip: resortTrip(),
        days: staleRows,
        inSitting: true,
      );
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('itinerary-planned-dives')),
        '0',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await savedDays(sitting!)).single;
      expect(saved.plannedDives, 0);
      // The spec: saving as Dive day with 0 keeps the type; the story still
      // reads it as a planned rest day (TripStoryDay.isPlannedRest).
      expect(saved.dayType, DayType.diveDay);
    },
  );

  testWidgets('saving a day as Rest plans it at none', (tester) async {
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await savedDays(sitting!)).single;
    expect(saved.dayType, DayType.rest);
    expect(saved.plannedDives, 0);
  });

  testWidgets('a non-number in planned dives is refused in place', (
    tester,
  ) async {
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      'two',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a whole number of dives, or leave it blank.'),
      findsOneWidget,
    );
    // The sheet stays open, and the sitting holds no change.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(sitting!.session.changedCardIds, isEmpty);
  });

  testWidgets('planned dives above the board cap are refused in place', (
    tester,
  ) async {
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '${kMaxPlannedDivesPerDay + 1}',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Plan at most $kMaxPlannedDivesPerDay dives a day.'),
      findsOneWidget,
    );
    // The sheet stays open, and the sitting holds no change.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(sitting!.session.changedCardIds, isEmpty);
  });

  testWidgets('planned dives at the board cap save', (tester) async {
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '$kMaxPlannedDivesPerDay',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(heldDay(sitting!, 'a').plannedDives, kMaxPlannedDivesPerDay);
  });

  testWidgets('a Rest day switched to Dive day goes back to the estimate', (
    tester,
  ) async {
    final rest = ItineraryDay(
      id: 'r',
      tripId: 'trip-1',
      dayNumber: 2,
      date: DateTime(2026, 3, 7),
      dayType: DayType.rest,
      plannedDives: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final sitting = await pumpTab(
      tester,
      trip: resortTrip(),
      days: [rest],
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dive Day').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await savedDays(sitting!)).single;
    expect(saved.dayType, DayType.diveDay);
    expect(saved.plannedDives, isNull);
  });

  testWidgets('on a Rest day the planned dives field reads 0 and is locked', (
    tester,
  ) async {
    await pumpTab(tester, trip: resortTrip(), days: staleRows, inSitting: true);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '2',
    );
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest').hitTestable());
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('itinerary-planned-dives')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.enabled, isFalse);
    expect(field.controller!.text, '0');
  });
}
