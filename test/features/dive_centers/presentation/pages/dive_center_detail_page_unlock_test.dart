import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_rental_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'dive_center_detail_page_unlock_harness.dart';

/// The dive centre page edits in place behind the phase 3 switch (issue
/// #4527): it opens locked, a sitting holds its cards, and one Save writes
/// it.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    final pencil = find.byTooltip(l.recordEdit_editCardTooltip(title));
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  EditSession<DiveCenter> sessionOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<DiveCenter>(
        tester.element(find.byType(RecordCardFrame<DiveCenter>).first),
      )!.session!;

  final header = DiveCenterCardId.header.localizedDisplayName(l);

  testWidgets('with the switch off there is no lock', (tester) async {
    await pumpDiveCenterPage(tester, unlockEditing: false);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpDiveCenterPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('Reef Divers').first);
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('website and closed in one sitting save as one entry', (
    tester,
  ) async {
    final harness = await pumpDiveCenterPage(tester);
    await unlock(tester);
    await openCard(tester, l.diveCenters_section_contact);
    await tester.enterText(
      find.byKey(const ValueKey('dive-center-edit-website')),
      'reefdivers.example',
    );
    await tester.pumpAndSettle();
    await openCard(tester, header);
    final closed = find.byKey(const ValueKey('dive-center-edit-closed'));
    await tester.ensureVisible(closed);
    await tester.tap(closed);
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'contact', 'header'});
    expect(harness.save.calls.single.after.website, 'reefdivers.example');
    expect(harness.save.calls.single.after.isPermanentlyClosed, isTrue);
  });

  testWidgets('an address typed with no coordinates looks them up before '
      'Save', (tester) async {
    final locations = FakeLocations(
      found: const LocationResult(latitude: 28.5, longitude: 34.5),
    );
    final harness = await pumpDiveCenterPage(tester, locations: locations);
    await unlock(tester);
    await openCard(tester, header);
    final street = find.byKey(const ValueKey('dive-center-edit-street'));
    await tester.ensureVisible(street);
    await tester.tap(street);
    await tester.enterText(street, '1 Sea St');
    await tester.pump();
    // Focus leaves the address.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(locations.asked, ['1 Sea St, Dahab']);

    // Save is asked for while the lookup is still out.
    await tester.tap(find.text(l.forms_save));
    await tester.pump();
    expect(harness.save.calls, isEmpty);
    locations.answer.complete();
    await tester.pumpAndSettle();

    final after = harness.save.calls.single.after;
    expect(after.street, '1 Sea St');
    expect(after.latitude, 28.5);
    expect(after.longitude, 34.5);
    expect(harness.save.calls.single.cards, {'header', 'map'});
  });

  testWidgets('a failed lookup saves without coordinates', (tester) async {
    final locations = FakeLocations();
    final harness = await pumpDiveCenterPage(tester, locations: locations);
    await unlock(tester);
    await openCard(tester, header);
    final street = find.byKey(const ValueKey('dive-center-edit-street'));
    await tester.ensureVisible(street);
    await tester.tap(street);
    await tester.enterText(street, '1 Sea St');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    locations.answer.complete();
    await tester.pumpAndSettle();

    await save(tester);

    final after = harness.save.calls.single.after;
    expect(after.street, '1 Sea St');
    expect(after.hasCoordinates, isFalse);
    expect(find.text(l.diveCenters_error_geocodeFailed), findsNothing);
  });

  testWidgets('fill hours show on Contact when set', (tester) async {
    await pumpDiveCenterPage(
      tester,
      center: reefDivers.copyWith(fillOpensAt: 8 * 60, fillClosesAt: 17 * 60),
    );

    expect(
      find.byKey(const ValueKey('dive_center_fill_hours')),
      findsOneWidget,
    );
    expect(find.text(l.diveCenters_section_fillHours), findsOneWidget);
  });

  testWidgets('a centre with no coordinates offers Map in the strip', (
    tester,
  ) async {
    await pumpDiveCenterPage(tester);
    await unlock(tester);

    expect(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(DiveCenterCardId.map.localizedDisplayName(l)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fill hours closing before opening stop Save', (tester) async {
    final harness = await pumpDiveCenterPage(tester);
    await unlock(tester);
    await openCard(tester, l.diveCenters_section_contact);
    sessionOf(
      tester,
    ).set(diveCenterFillHoursField, (opensAt: 17 * 60, closesAt: 8 * 60));
    await tester.pumpAndSettle();
    expect(find.text(l.diveCenters_fillHours_errorOrder), findsOneWidget);

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpDiveCenterPage(tester);
    await unlock(tester);
    sessionOf(tester).set(diveCenterNotesField, 'Hi');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a rental note and a phone change are one entry', (tester) async {
    final harness = await pumpDiveCenterPage(tester);
    harness.save.runHeld = false;
    await unlock(tester);
    final session = sessionOf(tester);
    // The harness has no database: the list starts empty instead of read.
    diveCenterRentalList.loadNone(session);
    diveCenterRentalList.set(session, [
      DiveCenterGearNote(
        id: 'n1',
        diveCenterId: 'dc1',
        gearType: EquipmentType.bcd,
        label: 'blue 3',
        verdict: RentalVerdict.worked,
        notedAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    session.set(diveCenterPhoneField, '+20 1');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'contact', 'rentalGear'});
  });
}
