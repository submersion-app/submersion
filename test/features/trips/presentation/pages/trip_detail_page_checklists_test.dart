import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'trip_detail_page_unlock_harness.dart';

/// A trip's checklists are held in its sitting behind the phase 3 switch
/// (issue #4527): every change, ticks included, waits for Save.
void main() {
  final l = AppLocalizationsEn();

  final packing = TripChecklistsHeld(
    checklists: [
      TripChecklist(
        id: 'c1',
        tripId: 't1',
        name: 'Packing',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
    items: [
      TripChecklistItem(
        id: 'i1',
        checklistId: 'c1',
        title: 'Mask',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  );

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> showChecklists(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_checklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packing'));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('locked, a checklist offers no tick or Add item, and its menu '
      'only saves it as a template', (tester) async {
    final harness = await pumpTripPage(tester, checklists: packing);
    await showChecklists(tester);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text(l.checklists_addItem), findsNothing);
    expect(find.text(l.checklists_addChecklist), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text(l.checklists_menu_saveAsTemplate), findsOneWidget);
    expect(find.text(l.checklists_menu_delete), findsNothing);
    expect(harness.checklistWrites, isEmpty);
  });

  testWidgets('in a sitting, a tick and a new checklist write nothing until '
      'Save, then one entry of the checklists card', (tester) async {
    final harness = await pumpTripPage(tester, checklists: packing);
    await unlock(tester);
    await showChecklists(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.checklists_addChecklist));
    await tester.pumpAndSettle();
    await tapText(tester, l.checklists_menu_newChecklist);
    await tester.enterText(find.byType(TextField).last, 'Paperwork');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Paperwork'), findsOneWidget);
    expect(harness.checklistWrites, isEmpty);
    await tapText(tester, l.forms_save);

    expect(harness.save.calls.single.cards, {'checklists'});
    expect(harness.checklistWrites, [
      'createChecklist Paperwork',
      'updateItem Mask done=true',
    ]);
  });

  testWidgets('Cancel after a tick writes nothing', (tester) async {
    final harness = await pumpTripPage(tester, checklists: packing);
    await unlock(tester);
    await showChecklists(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tapText(tester, l.common_action_cancel);
    // The sitting has a change: Cancel asks before discarding it.
    await tapText(tester, l.forms_discard_discard);

    expect(harness.save.calls, isEmpty);
    expect(harness.checklistWrites, isEmpty);
    // Locked again, the block shows what is stored.
    await tester.tap(find.text('Packing'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('Save as template from a held checklist makes the template at '
      'once, from what the page shows', (tester) async {
    final harness = await pumpTripPage(tester, checklists: packing);
    await unlock(tester);
    await showChecklists(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tapText(tester, l.checklists_menu_saveAsTemplate);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(harness.checklistWrites, ['saveAsTemplate Packing Mask:true']);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('Save as template from a sitting that moved the start date '
      'turns due dates into offsets from the new start', (tester) async {
    await pumpTripPage(tester, checklists: packing);
    await unlock(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(RecordCardFrame<Trip>).first),
    )!.session!.set(tripDatesField, (
      start: DateTime(2030, 7, 1),
      end: DateTime(2030, 7, 8),
    ));
    await tester.pumpAndSettle();
    await showChecklists(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tapText(tester, l.checklists_menu_saveAsTemplate);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final fake =
        container.read(tripChecklistRepositoryProvider)
            as FakeTripChecklistItems;
    expect(fake.templateStarts, [DateTime(2030, 7, 1)]);
  });
}
