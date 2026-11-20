import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'course_detail_page_unlock_harness.dart';

/// A new course opens on the course page, already unlocked (issue #4527,
/// phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('course-edit-name'));

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(nameField(), name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  testWidgets('a new course opens unlocked with Status and Details open', (
    tester,
  ) async {
    await pumpNewCoursePage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.courses_title_new), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(find.byKey(const ValueKey('course-edit-location')), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byType(CourseRequirementsSection), findsNothing);
  });

  testWidgets('Save waits for the first entry, then pops the id', (
    tester,
  ) async {
    final harness = await pumpNewCoursePage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeName(tester, 'Nitrox');
    await tapSave(tester);
    final created = harness.save.creates.single.course;
    expect(created.name, 'Nitrox');
    expect(created.diverId, 'd1');
    expect(created.agency, 'padi');
    // It pops its id, where the form went to the course and threw away
    // the stack under it.
    expect(harness.popped, created.id);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewCoursePage(tester, embedded: true);
    await typeName(tester, 'Nitrox');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.course.id]);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewCoursePage(tester);
    await typeName(tester, 'Nitrox');

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('an untouched new course leaves without asking', (tester) async {
    final harness = await pumpNewCoursePage(tester);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewCoursePage(tester);
    await typeName(tester, 'Nitrox');
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.fail = false;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.course.id,
      harness.save.creates.first.course.id,
    );
  });
}
