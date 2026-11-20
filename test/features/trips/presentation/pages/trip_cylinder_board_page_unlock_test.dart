import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/editing/trip_cylinder_events_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// The cylinder board is a satellite page of its trip behind the phase 3
/// switch (issue #4527, decision 9): alone it has a lock of its own and
/// its Save is one entry on the trip; pushed from an unlocked trip it joins
/// that sitting.
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime.utc(2026);

  final board = TripCylindersHeld(
    slots: [
      TripCylinder(
        id: 'c1',
        tripId: 't1',
        label: 'Truck 1',
        createdAt: at,
        updatedAt: at,
      ),
    ],
  );

  Future<TripPageHarness> pumpBoard(WidgetTester tester) => pumpTripPage(
    tester,
    board: board,
    wrap: (_) => const TripCylinderBoardPage(tripId: 't1'),
  );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> openSlotMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('slot-menu-c1')));
    await tester.pumpAndSettle();
  }

  Future<void> deleteSlot(WidgetTester tester) async {
    await openSlotMenu(tester);
    await tapText(tester, l.common_action_delete);
    await tester.tap(find.widgetWithText(FilledButton, l.common_action_delete));
    await tester.pumpAndSettle();
  }

  testWidgets('opened alone it opens locked: no Add, and the slot menu offers '
      'only Log dive', (tester) async {
    final harness = await pumpBoard(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byKey(const Key('board-add')), findsNothing);
    await openSlotMenu(tester);
    expect(find.text(l.trips_cylinders_action_logDive), findsOneWidget);
    expect(find.text(l.trips_cylinders_action_fill), findsNothing);
    expect(find.text(l.common_action_delete), findsNothing);
    expect(harness.gearWrites, isEmpty);
  });

  testWidgets('alone: unlock, delete a slot, Save writes one entry on the '
      'trip', (tester) async {
    final harness = await pumpBoard(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    await deleteSlot(tester);
    expect(find.text('Truck 1'), findsNothing);
    expect(harness.gearWrites, isEmpty);
    await tapText(tester, l.forms_save);

    expect(harness.save.calls.single.cards, {'cylinders'});
    expect(harness.gearWrites, ['deleteCylinder c1']);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('Log dive is offered on a stored slot and not on one made in '
      'the sitting', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final session = RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(TripCylinderSlotCard)),
    )!.session!;
    await TripBoardHold(
      session: session,
      board: tripCylindersList(
        cylinders: FakeTripBoard(board, []),
        copier: TripFillPassportCopier(),
      ),
    ).addSlots([
      TripCylinder(
        id: 'n1',
        tripId: 't1',
        label: 'Truck 2',
        sortOrder: 1,
        createdAt: at,
        updatedAt: at,
      ),
    ]);
    await tester.pumpAndSettle();

    await openSlotMenu(tester);
    expect(find.text(l.trips_cylinders_action_logDive), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot-menu-n1')));
    await tester.pumpAndSettle();
    expect(find.text(l.trips_cylinders_action_logDive), findsNothing);
    expect(find.text(l.trips_cylinders_action_fill), findsOneWidget);
  });

  testWidgets('pushed from an unlocked trip it joins its sitting with Done, '
      "and the trip's Save writes what changed there", (tester) async {
    final harness = await pumpTripPage(tester, board: board);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_gear));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Truck 1'));
    await tester.pumpAndSettle();

    expect(find.byType(TripCylinderBoardPage), findsOneWidget);
    expect(find.text(l.common_action_done), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await deleteSlot(tester);
    await tapText(tester, l.common_action_done);

    expect(find.byType(TripCylinderBoardPage), findsNothing);
    expect(harness.gearWrites, isEmpty);
    await tapText(tester, l.forms_save);

    expect(harness.save.calls.single.cards, {'cylinders'});
    expect(harness.gearWrites, ['deleteCylinder c1']);
  });

  testWidgets('pushed from a locked trip it has its own lock', (tester) async {
    await pumpTripPage(tester, board: board);
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_gear));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Truck 1'));
    await tester.pumpAndSettle();

    expect(find.byType(TripCylinderBoardPage), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(find.text(l.common_action_done), findsNothing);
  });

  testWidgets("a day's planned dives set on the strip are the itinerary "
      'day the sitting holds: the forecast follows before Save, and Save '
      'writes that day once', (tester) async {
    final june1 = ItineraryDay(
      id: 'i1',
      tripId: 't1',
      dayNumber: 1,
      date: DateTime(2030, 6, 1),
      dayType: DayType.diveDay,
      createdAt: at,
      updatedAt: at,
    );
    final harness = await pumpTripPage(
      tester,
      board: board,
      days: [june1],
      wrap: (_) => const TripCylinderBoardPage(tripId: 't1'),
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forecast-day-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-more')));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    final session = RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(TripCylinderSlotCard)),
    )!.session!;
    final held = tripItineraryDays().current(session)!;
    expect(held.single.id, 'i1');
    expect(held.single.plannedDives, 1);
    // The forecast reads the held day: its chip shows a plan of its own.
    expect(
      find.descendant(
        of: find.byKey(const Key('forecast-day-0')),
        matching: find.byIcon(Icons.edit_calendar),
      ),
      findsOneWidget,
    );
    expect(harness.itinerary.updated, isEmpty);

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(harness.save.calls.single.cards, {'itineraryDays'});
    expect(harness.itinerary.updated.single.plannedDives, 1);
    expect(harness.itinerary.saved, isEmpty);
  });

  testWidgets('the unlocked board waits for the itinerary before it draws '
      'the forecast, so a planned dive set then is held', (tester) async {
    final harness = await pumpTripPage(
      tester,
      board: board,
      wrap: (_) => const TripCylinderBoardPage(tripId: 't1'),
    );
    final gate = Completer<void>();
    harness.itinerary.gate = gate;
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pump();

    expect(find.byKey(const Key('forecast-day-0')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forecast-day-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-more')));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    final session = RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(TripCylinderSlotCard).first),
    )!.session!;
    expect(tripItineraryDays().current(session)!.single.plannedDives, 1);
  });

  testWidgets('when the itinerary cannot be read the strip shows its days '
      'and offers no edit', (tester) async {
    final harness = await pumpTripPage(
      tester,
      board: board,
      wrap: (_) => const TripCylinderBoardPage(tripId: 't1'),
    );
    harness.itinerary.failRead = true;
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    final chip = tester.widget<ActionChip>(
      find.byKey(const Key('forecast-day-0')),
    );
    expect(chip.onPressed, isNull);
    expect(harness.itinerary.saved, isEmpty);
  });
}
