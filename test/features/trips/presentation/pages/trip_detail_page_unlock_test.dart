import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tab.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';
import 'trip_page_drag_helpers.dart';

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

  // The header block is on the Overview, with the rest of the trip summary,
  // not above the tab row on every tab (issue #4927).
  testWidgets('the header pencil is on the Overview, under the tab row, and '
      'on no other tab', (tester) async {
    await pumpTripPage(tester);
    await unlock(tester);
    final pencil = find.byTooltip(
      l.recordEdit_editCardTooltip(l.settings_conflict_ref_trip),
    );

    expect(pencil, findsOneWidget);
    expect(
      tester.getRect(pencil).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(TabBar)).bottom),
    );

    await showTab(tester, l.trips_detail_tab_gear);
    expect(pencil, findsNothing);
  });

  testWidgets('the header editor opens on the Overview, under the tab row', (
    tester,
  ) async {
    await pumpTripPage(tester);
    await unlock(tester);

    await openCard(tester, l.settings_conflict_ref_trip);

    final editor = tester.getRect(find.byKey(const Key('trip-edit-name')));
    final tabs = tester.getRect(find.byType(TabBar));
    expect(editor.top, greaterThanOrEqualTo(tabs.bottom));
  });

  testWidgets('a Save refused for a blank name on another tab brings the '
      'header editor into view on the Overview', (tester) async {
    await pumpTripPage(tester);
    await unlock(tester);
    sessionOf(tester).set(tripNameField, ' ');
    await tester.pumpAndSettle();
    await showTab(tester, l.trips_detail_tab_gear);

    await save(tester);

    expect(find.byKey(const Key('trip-edit-name')), findsOneWidget);
    expect(find.text(l.trips_edit_validation_nameRequired), findsOneWidget);
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
      TripDetailTab.overview.index,
    );
  });

  testWidgets("a Save refused for a blank name while the story shows a day "
      "brings the story's Trip page into view with the header editor", (
    tester,
  ) async {
    final today = DateTime.now();
    await pumpTripPage(
      tester,
      trip: redSea.copyWith(
        startDate: DateTime(today.year, today.month, today.day - 2),
        endDate: DateTime(today.year, today.month, today.day + 2),
      ),
    );
    // A trip under way opens its story on today.
    expect(find.byType(TripStoryTripPage), findsNothing);
    await unlock(tester);
    sessionOf(tester).set(tripNameField, ' ');
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.byType(TripStoryTripPage), findsOneWidget);
    expect(find.byKey(const Key('trip-edit-name')), findsOneWidget);
  });

  // On a phone the open editor needs the room the day picker takes: the
  // picker folds while a card is open on the story's Trip page, and comes
  // back when the last one closes (issue #4927).
  group('the story day picker', () {
    final past = redSea.copyWith(
      startDate: DateTime(2024, 6, 1),
      endDate: DateTime(2024, 6, 8),
    );

    testWidgets('folds while the header card is open on the Trip page, and '
        'comes back at Done', (tester) async {
      await pumpTripPage(tester, trip: past);
      await unlock(tester);
      expect(find.byType(TripDayPicker), findsOneWidget);

      await openCard(tester, l.settings_conflict_ref_trip);
      expect(find.byType(TripDayPicker), findsNothing);

      await tester.tap(find.text(l.common_action_done).first);
      await tester.pumpAndSettle();
      expect(find.byType(TripDayPicker), findsOneWidget);
    });

    testWidgets('folds while the Notes card is open on the Trip page', (
      tester,
    ) async {
      await pumpTripPage(tester, trip: past.copyWith(notes: 'Windy'));
      await unlock(tester);

      await openCard(tester, notes);

      expect(find.byType(TripDayPicker), findsNothing);
    });

    testWidgets('stays on a day page while its Day plan is open', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Under way, so the story opens on today.
      await pumpTripPage(
        tester,
        trip: redSea.copyWith(
          startDate: today.subtract(const Duration(days: 1)),
          endDate: today.add(const Duration(days: 1)),
        ),
      );

      await tester.tap(find.byKey(TripStoryDayPage.editNoteKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-edit-day-note')), findsOneWidget);
      expect(find.byType(TripDayPicker), findsOneWidget);
    });
  });

  // Every field of the open header editor scrolls into view with the
  // Overview it sits on, under the tab row.
  for (final (name, size, embedded) in [
    ('a phone', const Size(402, 874), false),
    ('a desktop window', const Size(1280, 800), false),
    ('the master-detail pane', const Size(900, 800), true),
  ]) {
    testWidgets('on $name every field of the open header editor drags into '
        'view, with the card below the tab row', (tester) async {
      await pumpTripPage(tester, size: size, embedded: embedded);
      await unlock(tester);
      await openCard(tester, l.settings_conflict_ref_trip);

      for (final key in [
        'trip-edit-type',
        'trip-edit-name',
        'trip-edit-start',
        'trip-edit-end',
        'trip-edit-return-flight',
        'trip-edit-location',
        'trip-edit-resort',
        'trip-edit-liveaboard-name',
      ]) {
        final field = find.byKey(Key(key), skipOffstage: false);
        // On the card's margin, clear of its fields and the focused
        // name's selection handle.
        await dragPageUntilShown(
          tester,
          field,
          bottom: size.height,
          from: Offset(8, size.height / 2),
        );
        expectFullyShown(tester, field, bottom: size.height);
        expect(
          tester.getRect(field).top,
          greaterThanOrEqualTo(tester.getRect(find.byType(TabBar)).bottom),
        );
      }
    });
  }

  // The header editor opens inside the Overview, so nothing is built again
  // and a card holding unreadable text keeps it.
  testWidgets('the header editor opens beside a Plan card holding text that '
      'is not a number, and the text stays', (tester) async {
    await pumpTripPage(tester);
    await unlock(tester);
    await openCard(tester, l.trips_overview_plan);
    final divesPerDay = find.byKey(const Key('trip-edit-dives-per-day'));
    await tester.enterText(divesPerDay, '1.5');
    await tester.pumpAndSettle();

    await openCard(tester, l.settings_conflict_ref_trip);

    expect(find.byKey(const Key('trip-edit-name')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const Key('trip-edit-dives-per-day'),
          skipOffstage: false,
        ),
        matching: find.text('1.5', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      RecordEditScope.maybeOf<Trip>(
        tester.element(find.byType(RecordCardFrame<Trip>).first),
      )!.invalidCardIds,
      {TripCardId.plan.name},
    );
  });

  testWidgets('an open Notes card keeps its text across the header editor '
      'opening and closing', (tester) async {
    await pumpTripPage(tester);
    await unlock(tester);
    await openCard(tester, notes);
    await tester.enterText(find.byKey(const Key('trip-edit-notes')), 'Half');
    await tester.pumpAndSettle();

    await openCard(tester, l.settings_conflict_ref_trip);
    expect(find.text('Half', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text(l.common_action_done).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-edit-name')), findsNothing);
    expect(find.byKey(const Key('trip-edit-notes')), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
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
        'a trip $kind shows the focused field and scrolls to its last', (
      tester,
    ) async {
      await pumpTripPage(tester, trip: trip, size: const Size(402, 874));
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      await tester.pumpAndSettle();
      await unlock(tester);
      await openCard(tester, l.settings_conflict_ref_trip);
      // The keyboard, as an iPhone 17 Pro shows it for the name field.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      const keyboardTop = 874.0 - 336;
      // A past trip's day picker folds while the editor is open, leaving
      // it the room (issue #4927).
      expect(find.byType(TripDayPicker), findsNothing);
      final name = tester.getRect(find.byKey(const Key('trip-edit-name')));
      expect(name.bottom, lessThanOrEqualTo(keyboardTop));
      await dragPageUntilShown(
        tester,
        find.byKey(const Key('trip-edit-liveaboard-name'), skipOffstage: false),
        bottom: keyboardTop,
        // On the card's margin, clear of the focused name's selection
        // handle.
        from: const Offset(8, 480),
      );
      expectFullyShown(
        tester,
        find.byKey(const Key('trip-edit-liveaboard-name'), skipOffstage: false),
        bottom: keyboardTop,
      );
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
