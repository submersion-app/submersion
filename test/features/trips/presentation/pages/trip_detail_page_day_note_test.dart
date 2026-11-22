import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// A day's note on the trip story, edited where it shows (issue #4527,
/// phase 3): the day's passage of the Notes, under its heading.
void main() {
  final l = AppLocalizationsEn();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  /// A trip under way, so the story opens on today: its second day.
  Trip underWay({String notes = 'Intro'}) => redSea.copyWith(
    startDate: today.subtract(const Duration(days: 1)),
    endDate: today.add(const Duration(days: 1)),
    notes: notes,
  );

  Future<void> addNote(WidgetTester tester) async {
    await tester.tap(find.byKey(TripStoryDayPage.editNoteKey));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  bool canSave(WidgetTester tester) =>
      tester.widget<RecordEditBar>(find.byType(RecordEditBar)).canSave;

  RecordEditController<Trip> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Trip>(
        tester.element(find.byType(RecordCardFrame<Trip>).first),
      )!;

  Finder dayNote() => find.descendant(
    of: find.byKey(const Key('trip-edit-day-note')),
    matching: find.byType(EditableText),
  );

  testWidgets('locked, Add day note unlocks with the Day plan open', (
    tester,
  ) async {
    await pumpTripPage(tester, trip: underWay());

    await addNote(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(TripDayPlanCardEditor), findsOneWidget);
    final note = tester.widget<EditableText>(dayNote());
    expect(note.controller.text, isEmpty);
    // Ready to write under the heading: the field has the caret, at the end.
    expect(note.focusNode.hasFocus, isTrue);
    expect(
      note.controller.selection,
      TextSelection.collapsed(offset: note.controller.text.length),
    );
  });

  testWidgets('the added heading alone is not a change', (tester) async {
    await pumpTripPage(tester, trip: underWay());
    await addNote(tester);

    expect(canSave(tester), isFalse);
  });

  testWidgets('a tap that only moves the caret is not a change', (
    tester,
  ) async {
    await pumpTripPage(tester, trip: underWay(notes: '## Day 2\nWreck'));
    await addNote(tester);

    await tester.tap(dayNote());
    await tester.pumpAndSettle();

    expect(canSave(tester), isFalse);
  });

  testWidgets('words under the heading are saved with it', (tester) async {
    final harness = await pumpTripPage(tester, trip: underWay());
    await addNote(tester);

    await tester.enterText(dayNote(), 'Sharks');
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.save.calls.single.cards, {'notes'});
    expect(harness.save.calls.single.after.notes, 'Intro\n\n## Day 2\nSharks');
  });

  testWidgets('a Save for another reason leaves the empty heading out', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester, trip: underWay());
    await addNote(tester);
    controllerOf(tester).session!.set(tripLocationField, 'Safaga');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'header'});
    expect(harness.save.calls.single.after.notes, 'Intro');
  });

  testWidgets('an existing passage is what the editor holds, and untouched '
      'notes are saved as they were loaded', (tester) async {
    const notes = 'Intro\n\n## Day 2\nWreck\n\n## Day 3\nReef';
    final harness = await pumpTripPage(tester, trip: underWay(notes: notes));
    await addNote(tester);
    expect(tester.widget<EditableText>(dayNote()).controller.text, 'Wreck');
    controllerOf(tester).session!.set(tripLocationField, 'Safaga');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.after.notes, notes);
  });

  testWidgets('the day passage changes only that passage', (tester) async {
    final harness = await pumpTripPage(
      tester,
      trip: underWay(notes: 'Intro\n\n## Day 2\nWreck\n\n## Day 3\nReef'),
    );
    await addNote(tester);

    await tester.enterText(dayNote(), 'Drift');
    await tester.pumpAndSettle();
    await save(tester);

    expect(
      harness.save.calls.single.after.notes,
      'Intro\n\n## Day 2\nDrift\n\n## Day 3\nReef',
    );
  });

  testWidgets('notes changed underneath while the Day plan is open are kept '
      'when the diver types', (tester) async {
    final harness = await pumpTripPage(tester, trip: underWay());
    await addNote(tester);

    // Another part of the sitting (or the stored trip followed) changes the
    // notes before the diver types here.
    controllerOf(tester).session!.set(tripNotesField, 'Intro, edited');
    await tester.pumpAndSettle();
    await tester.enterText(dayNote(), 'Sharks');
    await tester.pumpAndSettle();
    await save(tester);

    expect(
      harness.save.calls.single.after.notes,
      'Intro, edited\n\n## Day 2\nSharks',
    );
  });
}
