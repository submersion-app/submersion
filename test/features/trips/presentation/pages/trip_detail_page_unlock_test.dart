import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// The trip page edits in place behind the phase 3 switch (issue #4527):
/// it opens locked, one sitting holds its cards across its tabs, and one
/// Save writes it.
void main() {
  final l = AppLocalizationsEn();

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

  Future<void> showTab(WidgetTester tester, String label) async {
    // A focused text field keeps its tab alive by itself; leave it first.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l.trips_detail_tooltip_moreOptions).last);
    await tester.pumpAndSettle();
  }

  EditSession<Trip> sessionOf(WidgetTester tester) {
    final element = tester.element(find.byType(RecordCardFrame<Trip>).first);
    return RecordEditScope.maybeOf<Trip>(element)!.session!;
  }

  final notes = l.trips_detail_sectionTitle_notes;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpTripPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('unlocked, the bar names the trip it is editing', (tester) async {
    await pumpTripPage(tester);

    await unlock(tester);

    expect(find.text(l.recordEdit_editingTitle('Red Sea')), findsOneWidget);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpTripPage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap on any tab writes', (tester) async {
    final harness = await pumpTripPage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('Bring the reef hook'));
    await tester.pumpAndSettle();
    for (final tab in [
      l.trips_detail_tab_itinerary,
      l.trips_detail_tab_gear,
      l.trips_detail_tab_checklist,
      l.trips_detail_tab_dives,
      l.trips_detail_tab_photos,
    ]) {
      await showTab(tester, tab);
    }

    expect(harness.save.calls, isEmpty);
    expect(harness.trips.deleted, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('the Gear and Checklist tabs offer no action with the switch '
      'on', (tester) async {
    await pumpTripPage(tester);

    await showTab(tester, l.trips_detail_tab_gear);
    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
    await showTab(tester, l.trips_detail_tab_checklist);
    expect(find.text(l.checklists_addChecklist), findsNothing);
    // Starting a pre-dive session makes a record of its own.
    expect(find.text(l.trips_detail_preDive_action), findsOneWidget);
  });

  testWidgets('notes in one sitting save as one entry and lock', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester);
    await unlock(tester);
    await openCard(tester, notes);
    await tester.enterText(
      find.byKey(const Key('trip-edit-notes')),
      'Bring the reef hook and gloves',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'notes'});
    expect(
      harness.save.calls.single.after.notes,
      'Bring the reef hook and gloves',
    );
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Bring the reef hook and gloves'), findsOneWidget);
  });

  testWidgets('empty Notes is offered in the strip on Overview and not on '
      'Itinerary', (tester) async {
    await pumpTripPage(tester, trip: redSea.copyWith(notes: ''));
    await unlock(tester);

    expect(
      find.descendant(of: find.byType(AddStrip), matching: find.text(notes)),
      findsOneWidget,
    );

    await showTab(tester, l.trips_detail_tab_itinerary);

    expect(
      find.descendant(of: find.byType(AddStrip), matching: find.text(notes)),
      findsNothing,
    );
  });

  testWidgets('an open Notes card survives a visit to the Itinerary tab', (
    tester,
  ) async {
    await pumpTripPage(tester);
    await unlock(tester);
    await openCard(tester, notes);
    await tester.enterText(find.byKey(const Key('trip-edit-notes')), 'Half');
    await tester.pumpAndSettle();

    await showTab(tester, l.trips_detail_tab_itinerary);
    await showTab(tester, l.trips_detail_tab_overview);

    expect(find.byKey(const Key('trip-edit-notes')), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
  });

  testWidgets('with the switch on the menu has no scans, and Delete is '
      'disabled locked', (tester) async {
    await pumpTripPage(tester, extraOverrides: ownerOverrides);
    await openMenu(tester);

    expect(find.text(l.trips_diveScan_findButton), findsNothing);
    expect(find.text(l.trips_photos_tooltip_scan), findsNothing);
    expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
    final delete = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text(l.trips_detail_action_delete),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(delete.enabled, isFalse);
  });

  testWidgets('unlocked and clean, Delete asks and deletes', (tester) async {
    final harness = await pumpTripPage(
      tester,
      extraOverrides: ownerOverrides,
      wrap: (page) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('list')),
        ),
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('list')),
          ),
          MaterialPageRoute<void>(builder: (_) => page),
        ],
      ),
    );
    await unlock(tester);
    await openMenu(tester);
    await tester.tap(find.text(l.trips_detail_action_delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.trips_detail_dialog_deleteConfirm));
    await tester.pumpAndSettle();

    expect(harness.trips.deleted, ['t1']);
  });

  testWidgets('a start date moved past today in a sitting keeps the prepare '
      'page until Save', (tester) async {
    final harness = await pumpTripPage(tester);
    await unlock(tester);
    final now = DateTime.now();
    sessionOf(tester).set(tripDatesField, (
      start: DateTime(now.year - 1, 6, 1),
      end: DateTime(now.year - 1, 6, 8),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TripPrepareOverview), findsOneWidget);

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(find.byType(TripPrepareOverview), findsNothing);
  });

  testWidgets('name, dates and notes in one sitting save as one entry', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester);
    await unlock(tester);
    await openCard(tester, l.settings_conflict_ref_trip);
    await tester.enterText(find.byKey(const Key('trip-edit-name')), 'Egypt');
    await tester.pumpAndSettle();
    sessionOf(tester).set(tripNotesField, 'Windy');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'header', 'notes'});
    expect(harness.save.calls.single.after.name, 'Egypt');
  });

  testWidgets('the header editor opens above the tab row on every tab', (
    tester,
  ) async {
    await pumpTripPage(tester);
    await unlock(tester);
    await showTab(tester, l.trips_detail_tab_gear);

    await openCard(tester, l.settings_conflict_ref_trip);

    final editor = tester.getRect(find.byKey(const Key('trip-edit-name')));
    final tabs = tester.getRect(find.byType(TabBar));
    expect(editor.bottom, lessThan(tabs.top));
  });

  for (final (kind, trip) in [
    ('to come', redSea),
    // A past trip's Overview has the story's day strip at its top.
    (
      'in the past',
      redSea.copyWith(
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 8),
      ),
    ),
  ]) {
    testWidgets('on a phone with the keyboard up, the open header editor of '
        'a trip $kind fits above the tab row', (tester) async {
      await pumpTripPage(tester, trip: trip, size: const Size(402, 874));
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      await tester.pumpAndSettle();
      await unlock(tester);
      await openCard(tester, l.settings_conflict_ref_trip);
      // The keyboard, as an iPhone 17 Pro shows it for the name field.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tabs = tester.getRect(find.byType(TabBar));
      expect(tabs.bottom, lessThanOrEqualTo(874 - 336));
    });
  }

  testWidgets('Cancel with changes asks first', (tester) async {
    final harness = await pumpTripPage(tester);
    await unlock(tester);
    sessionOf(tester).set(tripNotesField, 'Changed');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.common_action_cancel).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets("with the switch on the summary card's rows open their tab", (
    tester,
  ) async {
    await pumpTripPage(tester);

    await tester.tap(find.text(l.trips_detail_tab_checklist).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l.trips_detail_preDive_action), findsOneWidget);
  });

  testWidgets('a failed Unhide leaves the sitting as it was', (tester) async {
    final harness = await pumpTripPage(
      tester,
      divers: twoDivers,
      activeDiverId: 'd2',
      extraOverrides: [isHiddenProvider.overrideWith((ref, key) async => true)],
    );
    harness.trips.failUnhide = true;
    await unlock(tester);
    final before = sessionOf(tester);

    await openMenu(tester);
    await tester.tap(find.text(l.sharedItems_unhideAction));
    await tester.pumpAndSettle();

    expect(find.text(l.common_error_tryAgain), findsOneWidget);
    expect(identical(sessionOf(tester), before), isTrue);
  });
}
