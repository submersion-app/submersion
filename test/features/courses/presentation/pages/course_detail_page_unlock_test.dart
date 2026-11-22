import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'course_detail_page_unlock_harness.dart';

/// The course page edits in place behind the phase 3 switch (issue #4527):
/// it opens locked, a sitting holds its cards, and one Save writes it.
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

  EditSession<Course> sessionOf(WidgetTester tester) {
    final element = tester.element(find.byType(RecordCardFrame<Course>).first);
    return RecordEditScope.maybeOf<Course>(element)!.session!;
  }

  final details = l.courses_section_details;
  final status = l.settings_conflict_ref_course;

  // The lock is the one way in (issue #4527, plan 12): no Edit pencil.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpCoursePage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('the pane header has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpCoursePage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
  });

  testWidgets('locked, no tap writes', (tester) async {
    final harness = await pumpCoursePage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    // With the switch on, Mark completed is in the Status editor only.
    expect(find.text(l.courses_action_markCompleted), findsNothing);
    await tester.tap(find.text('Reef'));
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('name and location in one sitting save as one entry and lock', (
    tester,
  ) async {
    final harness = await pumpCoursePage(tester);
    await unlock(tester);
    await openCard(tester, status);
    await tester.enterText(
      find.byKey(const ValueKey('course-edit-name')),
      'Rescue Diver',
    );
    await openCard(tester, details);
    await tester.enterText(
      find.byKey(const ValueKey('course-edit-location')),
      'Blue Hole',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(harness.save.calls.single.cards, {'status', 'details'});
    expect(harness.save.calls.single.after.name, 'Rescue Diver');
    expect(harness.save.calls.single.after.location, 'Blue Hole');
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    final harness = await pumpCoursePage(tester);
    await unlock(tester);
    await openCard(tester, status);
    await tester.enterText(find.byKey(const ValueKey('course-edit-name')), '');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls, isEmpty);
    expect(find.text(l.courses_validation_nameRequired), findsOneWidget);
  });

  testWidgets('Mark completed in the Status editor shows Completed at once '
      'and writes at Save', (tester) async {
    final harness = await pumpCoursePage(tester);
    await unlock(tester);
    await openCard(tester, status);

    await tester.tap(find.text(l.courses_action_markCompleted));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(l.courses_status_completed), findsWidgets);
    expect(harness.save.calls, isEmpty);

    await save(tester);

    expect(harness.save.calls.single.cards, {'details'});
    expect(harness.save.calls.single.after.completionDate, isNotNull);
  });

  testWidgets('the Instructor card shows a number alone', (tester) async {
    await pumpCoursePage(
      tester,
      course: rescue.copyWith(instructorNumber: '77'),
    );

    expect(find.text(l.courses_section_instructor), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
  });

  testWidgets('the Instructor card names a linked buddy when there is no '
      'name', (tester) async {
    final sam = Buddy(
      id: 'b1',
      name: 'Sam Instructor',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    await pumpCoursePage(
      tester,
      course: rescue.copyWith(instructorId: 'b1'),
      buddies: [sam],
    );

    expect(find.text(l.courses_section_instructor), findsOneWidget);
    expect(find.text('Sam Instructor'), findsOneWidget);
  });

  testWidgets('empty Instructor, Earned certifications and Notes are offered '
      'in the strip', (tester) async {
    await pumpCoursePage(tester);
    await unlock(tester);

    for (final title in [
      l.courses_section_instructor,
      l.courses_section_earnedCertifications,
      l.courses_section_notes,
    ]) {
      expect(
        find.descendant(of: find.byType(AddStrip), matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
  });

  testWidgets('a failed certifications read says so with the switch on', (
    tester,
  ) async {
    await pumpCoursePage(tester, certificationsFail: true);

    expect(find.text(l.courses_error_loadingCertification), findsOneWidget);
  });

  testWidgets('notes added from the strip are saved', (tester) async {
    final harness = await pumpCoursePage(tester);
    await unlock(tester);
    final chip = find.descendant(
      of: find.byType(AddStrip),
      matching: find.text(l.courses_section_notes),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pool sessions');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'notes'});
    expect(harness.save.calls.single.after.notes, 'Pool sessions');
  });

  testWidgets('Training dives fades as calculated', (tester) async {
    await pumpCoursePage(tester);
    await unlock(tester);

    final fades = tester.widgetList<RecordCardFade<Course>>(
      find.byType(RecordCardFade<Course>),
    );
    expect(
      fades.where((f) => f.reason == RecordCardFadeReason.calculated),
      isNotEmpty,
    );
    expect(
      find.ancestor(
        of: find.text(l.courses_section_trainingDives),
        matching: find.byType(RecordCardFade<Course>),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the documents card holds a detach until Save', (tester) async {
    await pumpCoursePage(tester);
    await unlock(tester);
    final session = sessionOf(tester);

    detachDocument(session, 'doc-1');
    await tester.pumpAndSettle();

    expect(sittingDocumentLinks(session).detach, {'doc-1'});
    expect(session.changedCardIds, contains('documents'));
  });

  testWidgets('a name set in the session is one change of Status', (
    tester,
  ) async {
    final harness = await pumpCoursePage(tester);
    await unlock(tester);
    sessionOf(tester).set(courseNameField, 'Renamed');
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'status'});
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpCoursePage(tester);
    await unlock(tester);
    await openCard(tester, details);
    await tester.enterText(
      find.byKey(const ValueKey('course-edit-location')),
      'Blue Hole',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
  group('requirements', () {
    final knowledge = CourseRequirementProgress(
      requirement: CourseRequirement(
        id: 'r1',
        courseId: 'k1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      linkedDives: const [],
    );
    final progress = CourseProgress(courseId: 'k1', requirements: [knowledge]);

    testWidgets('locked, the Requirements card offers no action', (
      tester,
    ) async {
      final harness = await pumpCoursePage(tester, progress: progress);

      expect(find.text('Knowledge development'), findsOneWidget);
      expect(find.byIcon(Icons.library_add_outlined), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(harness.save.calls, isEmpty);
    });

    testWidgets('a tick and a name change are one save', (tester) async {
      final harness = await pumpCoursePage(tester, progress: progress);
      harness.save.runHeld = false;
      await unlock(tester);
      final session = sessionOf(tester);
      // The harness has no database: the list starts empty instead of read.
      courseRequirementsList.loadNone(session);
      courseRequirementsList.set(session, [knowledge]);
      courseRequirementsList.set(
        session,
        withRequirementTicked([knowledge], 'r1', true),
      );
      session.set(courseNameField, 'Rescue Diver');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.cards, {'status', 'requirements'});
    });
  });
  group('opening and operations', () {
    testWidgets('opened with mode=edit, the page is unlocked', (tester) async {
      await pumpCoursePage(tester, openUnlocked: true);

      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets("the pane's edit opens the page unlocked, Cancel returns to "
        'view', (tester) async {
      var ended = 0;
      await pumpCoursePage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      expect(find.textContaining('Editing'), findsOneWidget);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(ended, 1);
    });

    testWidgets("the pane's Save updates the course", (tester) async {
      var ended = 0;
      final harness = await pumpCoursePage(
        tester,
        embedded: true,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      sessionOf(tester).set(courseLocationField, 'Blue Hole');
      await tester.pumpAndSettle();

      await save(tester);

      expect(harness.save.calls.single.after.location, 'Blue Hole');
      expect(harness.stored.state!.location, 'Blue Hole');
      expect(ended, 1);
    });

    testWidgets("the pane's Save creates no course", (tester) async {
      final harness = await pumpCoursePage(
        tester,
        embedded: true,
        openUnlocked: true,
      );
      sessionOf(tester).set(courseLocationField, 'Blue Hole');
      await tester.pumpAndSettle();

      await save(tester);

      // The one write is the update of the course the pane opened on.
      expect(harness.save.calls, hasLength(1));
      expect(harness.save.calls.single.after.id, 'k1');
    });

    testWidgets('locked, Delete is disabled under "Unlock to use these"', (
      tester,
    ) async {
      await pumpCoursePage(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      final delete = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, l.common_action_delete),
      );
      expect(delete.enabled, isFalse);
    });

    testWidgets('Export training log works locked', (tester) async {
      await pumpCoursePage(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      final export = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(
          PopupMenuItem<String>,
          l.courses_action_exportTrainingLog,
        ),
      );
      expect(export.enabled, isTrue);
    });

    testWidgets('unlocked and clean, Delete asks', (tester) async {
      await pumpCoursePage(tester);
      await unlock(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(RecordEditBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, l.common_action_delete),
      );
      expect(item.enabled, isTrue);
      expect(find.text(l.recordEdit_unlockToUseThese), findsNothing);
      await tester.tap(find.text(l.common_action_delete));
      await tester.pumpAndSettle();

      expect(find.text(l.courses_dialog_deleteTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_cancel),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
