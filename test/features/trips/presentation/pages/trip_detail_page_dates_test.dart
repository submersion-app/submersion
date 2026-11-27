import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/shared_items_fixture.dart';
import 'trip_detail_page_unlock_harness.dart';

/// A trip's dates changed in a sitting ask which dives in the new dates
/// join it, at Save, in the same History entry (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();

  final candidates = [
    DiveCandidate(
      dive: Dive(id: 'v1', dateTime: DateTime(2030, 5, 31, 9)),
    ),
  ];

  RecordEditController<Trip> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Trip>(
        tester.element(find.byType(RecordCardFrame<Trip>).first),
      )!;

  Future<TripPageHarness> pumpWithNewStart(
    WidgetTester tester, {
    List<DiveCandidate>? found,
  }) async {
    final harness = await pumpTripPage(
      tester,
      activeDiverId: 'd1',
      candidates: found ?? candidates,
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    controllerOf(tester).session!.set(tripDatesField, (
      start: DateTime(2030, 5, 30),
      end: DateTime(2030, 6, 8),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> addChosen(WidgetTester tester) async {
    await tester.tap(find.text(l.trips_diveScan_addButton(1)));
    await tester.pumpAndSettle();
  }

  testWidgets('dates changed: the question is asked once and the chosen dives '
      'are assigned in the same entry', (tester) async {
    final harness = await pumpWithNewStart(tester);

    await tapSave(tester);
    expect(harness.tripDives.asked.single.start, DateTime(2030, 5, 30));
    expect(harness.tripDives.assigned, isEmpty);
    await addChosen(tester);

    expect(harness.save.calls.single.cards, {'header'});
    expect(harness.tripDives.assigned.single, ['v1']);
    expect(find.text(l.trips_diveScan_added(1)), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('dismissing the question saves the dates with no dives', (
    tester,
  ) async {
    final harness = await pumpWithNewStart(tester);

    await tapSave(tester);
    await tester.tap(find.text(l.trips_diveScan_cancel).last);
    await tester.pumpAndSettle();

    expect(harness.save.calls.single.after.startDate, DateTime(2030, 5, 30));
    expect(harness.tripDives.assigned, isEmpty);
  });

  // A trip shared with the diver is another profile's: the dives that may
  // join it are the active profile's own, as the form searched them.
  testWidgets("a shared trip's new dates ask about the active profile's "
      'dives, not the owner\'s', (tester) async {
    final harness = await pumpTripPage(
      tester,
      divers: twoDivers,
      activeDiverId: 'd2',
      candidates: candidates,
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    controllerOf(tester).session!.set(tripDatesField, (
      start: DateTime(2030, 5, 30),
      end: DateTime(2030, 6, 8),
    ));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(harness.tripDives.asked.single.diverId, 'd2');
  });

  testWidgets('unchanged dates ask nothing', (tester) async {
    final harness = await pumpTripPage(
      tester,
      activeDiverId: 'd1',
      candidates: candidates,
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    controllerOf(tester).session!.set(tripNotesField, 'Windy');
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(harness.tripDives.asked, isEmpty);
    expect(harness.save.calls, hasLength(1));
  });

  testWidgets('no dives in the new dates ask nothing', (tester) async {
    final harness = await pumpWithNewStart(tester, found: const []);

    await tapSave(tester);

    expect(find.text(l.trips_diveScan_title), findsNothing);
    expect(harness.save.calls, hasLength(1));
  });

  testWidgets('a failed Save assigns nothing and the next Save asks again', (
    tester,
  ) async {
    final harness = await pumpWithNewStart(tester);
    harness.save.fail = true;

    await tapSave(tester);
    await addChosen(tester);

    expect(harness.tripDives.assigned, isEmpty);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.fail = false;
    await tapSave(tester);
    await addChosen(tester);

    expect(harness.tripDives.asked, hasLength(2));
    expect(harness.tripDives.assigned.single, ['v1']);
  });

  testWidgets('dates put back after a failed Save assign nothing', (
    tester,
  ) async {
    final harness = await pumpWithNewStart(tester);
    harness.save.fail = true;
    await tapSave(tester);
    await addChosen(tester);
    harness.save.fail = false;

    controllerOf(tester).session!
      ..set(tripDatesField, (start: redSea.startDate, end: redSea.endDate))
      ..set(tripNotesField, 'Windy');
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(harness.tripDives.asked, hasLength(1));
    expect(harness.tripDives.assigned, isEmpty);
    expect(harness.save.calls, hasLength(1));
  });

  testWidgets('Cancel after the question assigns nothing', (tester) async {
    final harness = await pumpWithNewStart(tester);
    harness.save.fail = true;
    await tapSave(tester);
    await addChosen(tester);

    await tester.tap(find.text(l.common_action_cancel).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.tripDives.assigned, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a candidate read that fails still saves, asking nothing', (
    tester,
  ) async {
    final harness = await pumpWithNewStart(tester);
    harness.tripDives.failRead = true;

    await tapSave(tester);

    expect(find.text(l.trips_diveScan_title), findsNothing);
    expect(harness.save.calls, hasLength(1));
    expect(harness.tripDives.assigned, isEmpty);
  });

  testWidgets('dates changed while the profile is still being read ask once '
      'it answers', (tester) async {
    final active = GatedActiveProfile();
    final harness = await pumpTripPage(
      tester,
      candidates: candidates,
      extraOverrides: [
        validatedCurrentDiverIdProvider.overrideWith((_) => active.read()),
      ],
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    controllerOf(tester).session!.set(tripDatesField, (
      start: DateTime(2030, 5, 30),
      end: DateTime(2030, 6, 8),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pump();
    active.settle('d1');
    await tester.pumpAndSettle();

    expect(harness.tripDives.asked, hasLength(1));
    expect(find.text(l.trips_diveScan_title), findsOneWidget);
  });
}
