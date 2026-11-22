import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../pages/trip_detail_page_unlock_harness.dart';

/// The trip Overview's Plan and Vessel cards edited in place (issue #4527,
/// phase 3).
void main() {
  final l = AppLocalizationsEn();
  final plan = l.trips_overview_plan;
  final vessel = l.trips_detail_sectionTitle_vessel;

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(title)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  EditSession<Trip> sessionOf(WidgetTester tester) {
    final element = tester.element(find.byType(RecordCardFrame<Trip>).first);
    return RecordEditScope.maybeOf<Trip>(element)!.session!;
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  group('Plan', () {
    testWidgets("the Plan editor's rows set only the plan card", (
      tester,
    ) async {
      final harness = await pumpTripPage(tester);
      await unlock(tester);
      await openCard(tester, plan);
      await tester.enterText(field('trip-edit-dives-per-day'), '3');
      await tester.enterText(field('trip-edit-expected-runtime'), '55');
      await tester.enterText(field('trip-edit-expected-dives'), '12');
      await tester.enterText(field('trip-edit-divers-sharing'), '3');
      await tester.pumpAndSettle();

      await save(tester);

      final saved = harness.save.calls.single;
      expect(saved.cards, {'plan'});
      expect(saved.after.divesPerDayTarget, 3);
      expect(saved.after.expectedRuntimeMinutes, 55);
      expect(saved.after.expectedDives, 12);
      expect(saved.after.diversSharingCylinders, 3);
    });

    testWidgets('a fractional expected dive count refuses the Save', (
      tester,
    ) async {
      final harness = await pumpTripPage(tester);
      await unlock(tester);
      await openCard(tester, plan);
      // A real change first, so Save is offered and must refuse.
      await tester.enterText(field('trip-edit-dives-per-day'), '3');
      await tester.enterText(field('trip-edit-expected-dives'), '2.5');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text(l.numberInput_invalidWholeNumber), findsOneWidget);
    });

    testWidgets('expected dives and runtime show on the Plan row when set', (
      tester,
    ) async {
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(expectedDives: 18, expectedRuntimeMinutes: 55),
      );

      expect(
        find.textContaining(l.trips_scrubber_expectedDives(18)),
        findsOneWidget,
      );
      expect(
        find.textContaining(l.trips_overview_plan_runtime(55)),
        findsOneWidget,
      );
    });

    testWidgets('locked with the switch on, the Plan row unlocks with the '
        'Plan card open', (tester) async {
      await pumpTripPage(tester);

      await tester.tap(find.text(plan));
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.byType(TripPlanCardEditor), findsOneWidget);
    });

    testWidgets('from the first day, Plan is offered in the strip', (
      tester,
    ) async {
      final now = DateTime.now();
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(
          startDate: DateTime(now.year - 1, 6, 1),
          endDate: DateTime(now.year - 1, 6, 8),
        ),
      );
      await unlock(tester);

      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(plan)),
        findsOneWidget,
      );
    });
  });

  group('Vessel', () {
    testWidgets('the Vessel card shows on the prepare page for a liveaboard', (
      tester,
    ) async {
      await pumpTripPage(tester, trip: liveaboard, vessel: mvBlue);

      expect(find.text('MV Blue'), findsOneWidget);
    });

    testWidgets('vessel fields are shown for a liveaboard', (tester) async {
      await pumpTripPage(
        tester,
        trip: liveaboard,
        vessel: mvBlue.copyWith(
          embarkPort: 'Port Ghalib',
          disembarkPort: 'Hurghada',
        ),
      );
      await unlock(tester);
      await openCard(tester, vessel);

      String text(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('trip-edit-vessel-name'), 'MV Blue');
      expect(text('trip-edit-vessel-operator'), 'Blue Waters');
      expect(text('trip-edit-vessel-embark'), 'Port Ghalib');
      expect(text('trip-edit-vessel-disembark'), 'Hurghada');
    });

    testWidgets('a vessel name and the plan in one sitting save as one entry', (
      tester,
    ) async {
      final harness = await pumpTripPage(
        tester,
        trip: liveaboard,
        vessel: mvBlue,
      );
      await unlock(tester);
      await openCard(tester, vessel);
      await tester.enterText(
        find.byKey(const Key('trip-edit-vessel-name')),
        'MV Red',
      );
      await tester.pumpAndSettle();
      sessionOf(tester).set(tripDivesPerDayField, 3.0);
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.cards, {'vessel', 'plan'});
      expect(harness.vessels.writes.single.vesselName, 'MV Red');
    });

    testWidgets('the vessel type selection is held until Save', (tester) async {
      final harness = await pumpTripPage(
        tester,
        trip: liveaboard,
        vessel: mvBlue,
      );
      await unlock(tester);
      await openCard(tester, vessel);
      await tester.tap(find.byKey(const Key('trip-edit-vessel-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.trips_vesselType_catamaran).last);
      await tester.pumpAndSettle();

      expect(harness.vessels.writes, isEmpty);
      await save(tester);

      expect(harness.vessels.writes.single.vesselType, 'catamaran');
    });

    testWidgets('capacity of zero stores none', (tester) async {
      final harness = await pumpTripPage(
        tester,
        trip: liveaboard,
        vessel: mvBlue.copyWith(capacity: 12),
      );
      await unlock(tester);
      await openCard(tester, vessel);
      await tester.enterText(
        find.byKey(const Key('trip-edit-vessel-capacity')),
        '0',
      );
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.vessels.writes.single.capacity, isNull);
    });

    testWidgets('the vessel name is required for a liveaboard', (tester) async {
      final harness = await pumpTripPage(tester, trip: liveaboard);
      await unlock(tester);
      sessionOf(tester).set(tripNotesField, 'Windy');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
      expect(find.byType(TripVesselCardEditor), findsOneWidget);
      expect(find.text(l.trips_edit_validation_vesselRequired), findsOneWidget);
    });

    testWidgets('a Save refused for the vessel name while Itinerary is in '
        'view moves to Overview and shows the card', (tester) async {
      final harness = await pumpTripPage(tester, trip: liveaboard);
      await unlock(tester);
      sessionOf(tester).set(tripNotesField, 'Windy');
      await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_itinerary));
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls, isEmpty);
      expect(find.byType(TripVesselCardEditor), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    });

    testWidgets('a liveaboard made a resort trip, then Cancel: the details '
        'stay', (tester) async {
      final harness = await pumpTripPage(
        tester,
        trip: liveaboard,
        vessel: mvBlue,
      );
      await unlock(tester);
      sessionOf(tester).set(tripTypeField, TripType.resort);
      await tester.pumpAndSettle();
      expect(find.text('MV Blue'), findsNothing);

      await tester.tap(find.text(l.common_action_cancel).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(harness.save.calls, isEmpty);
      expect(find.text('MV Blue'), findsOneWidget);
    });
  });

  testWidgets('an unreadable capacity left behind by a type change does not '
      'refuse the Save', (tester) async {
    final harness = await pumpTripPage(
      tester,
      trip: liveaboard,
      vessel: mvBlue,
    );
    await unlock(tester);
    await openCard(tester, vessel);
    await tester.enterText(
      find.byKey(const Key('trip-edit-vessel-capacity')),
      '1.5',
    );
    await tester.pumpAndSettle();
    expect(find.text(l.numberInput_invalidWholeNumber), findsOneWidget);

    sessionOf(tester).set(tripTypeField, TripType.resort);
    await tester.pumpAndSettle();
    expect(find.byType(TripVesselCardEditor), findsNothing);
    await save(tester);

    expect(harness.save.calls, hasLength(1));
  });

  testWidgets('a vessel that could not be read refuses the Save, and the '
      'card offers to read it again', (tester) async {
    final harness = await pumpTripPage(
      tester,
      trip: liveaboard,
      vessel: mvBlue,
    );
    harness.vessels.failRead = true;
    await unlock(tester);
    sessionOf(tester).set(tripNotesField, 'Windy');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(find.byType(TripVesselCardEditor), findsOneWidget);

    harness.vessels.failRead = false;
    await tester.tap(find.text(l.common_action_retry));
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.save.calls, hasLength(1));
  });

  testWidgets('a Save refused for the vessel name while the story shows a '
      'day brings the Trip page and its Vessel card into view', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final harness = await pumpTripPage(
      tester,
      trip: liveaboard.copyWith(
        startDate: today.subtract(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 1)),
      ),
    );
    await unlock(tester);
    sessionOf(tester).set(tripNotesField, 'Windy');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(find.byType(TripVesselCardEditor), findsOneWidget);
  });
}
