import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// A trip's itinerary held in the trip page's sitting (issue #4527, phase
/// 3): Generate and the day sheet write nothing until Save.
void main() {
  final l = AppLocalizationsEn();

  /// Two days of [redSea]'s eight planned.
  final days = [
    for (final (i, date) in [
      DateTime(2030, 6, 1),
      DateTime(2030, 6, 2),
    ].indexed)
      ItineraryDay(
        id: 'i$i',
        tripId: 't1',
        dayNumber: i + 1,
        date: date,
        dayType: DayType.diveDay,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];

  Future<void> showItinerary(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_itinerary));
    await tester.pumpAndSettle();
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> editFirstDay(WidgetTester tester, String notes) async {
    await tester.tap(find.byType(ItineraryDayCard).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(EditableText),
          )
          .at(1),
      notes,
    );
    await tester.tap(find.text(l.common_action_save).last);
    await tester.pumpAndSettle();
  }

  RecordEditController<Trip> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Trip>(tester.element(find.byType(TabBar)))!;

  testWidgets('locked with the switch on, no generate and no sheet', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester, days: days);
    await showItinerary(tester);

    expect(find.byKey(const Key('trip-itinerary-generate')), findsNothing);
    await tester.tap(find.byType(ItineraryDayCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(harness.itinerary.saved, isEmpty);
    expect(harness.itinerary.updated, isEmpty);
  });

  testWidgets('in a sitting, generate writes nothing until Save', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester, days: days);
    await unlock(tester);
    await showItinerary(tester);

    await tester.tap(find.byKey(const Key('trip-itinerary-generate')));
    await tester.pumpAndSettle();

    expect(harness.itinerary.saved, isEmpty);
    expect(find.byKey(const Key('trip-itinerary-generate')), findsNothing);

    await save(tester);

    expect(harness.save.calls.single.cards, {'itineraryDays'});
    expect(harness.itinerary.saved, hasLength(6));
  });

  testWidgets('in a sitting, a day saved in the sheet writes nothing until '
      'Save', (tester) async {
    final harness = await pumpTripPage(tester, days: days);
    await unlock(tester);
    await showItinerary(tester);

    await editFirstDay(tester, 'Wreck');

    expect(harness.itinerary.updated, isEmpty);
    expect(find.text('Wreck'), findsOneWidget);

    await save(tester);

    expect(harness.itinerary.updated.single.notes, 'Wreck');
  });

  testWidgets('a rest day still forces zero dives in hold mode', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester, days: days);
    await unlock(tester);
    await showItinerary(tester);
    await tester.tap(find.byType(ItineraryDayCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.trips_dayType_rest).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.common_action_save).last);
    await tester.pumpAndSettle();

    await save(tester);

    final saved = harness.itinerary.updated.single;
    expect(saved.dayType, DayType.rest);
    expect(saved.plannedDives, 0);
  });

  testWidgets('days generated and a day edited save as one entry with the '
      'header', (tester) async {
    final harness = await pumpTripPage(tester, days: days);
    await unlock(tester);
    controllerOf(tester).session!.set(tripLocationField, 'Safaga');
    await showItinerary(tester);
    await tester.tap(find.byKey(const Key('trip-itinerary-generate')));
    await tester.pumpAndSettle();
    await editFirstDay(tester, 'Wreck');

    await save(tester);

    expect(harness.save.calls.single.cards, {'header', 'itineraryDays'});
    expect(harness.itinerary.saved, hasLength(6));
    expect(harness.itinerary.updated, hasLength(1));
  });

  testWidgets('the same, then Cancel: nothing written', (tester) async {
    final harness = await pumpTripPage(tester, days: days);
    await unlock(tester);
    await showItinerary(tester);
    await tester.tap(find.byKey(const Key('trip-itinerary-generate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.common_action_cancel).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(harness.itinerary.saved, isEmpty);
  });

  testWidgets('dates widened in a sitting offer the new missing days', (
    tester,
  ) async {
    final all = [
      for (var i = 0; i < 8; i++)
        days.first.copyWith(id: 'd$i', date: DateTime(2030, 6, 1 + i)),
    ];
    await pumpTripPage(tester, days: all);
    await unlock(tester);
    await showItinerary(tester);
    expect(find.byKey(const Key('trip-itinerary-generate')), findsNothing);

    controllerOf(tester).session!.set(tripDatesField, (
      start: DateTime(2030, 6, 1),
      end: DateTime(2030, 6, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-itinerary-generate')), findsOneWidget);
  });
}
