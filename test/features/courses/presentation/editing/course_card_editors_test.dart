import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_editors.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Each course card editor sets only its own card's values, with the edit
/// form's widgets and rules (issue #4527, phase 3).
void main() {
  Course course({DateTime? start, DateTime? completion}) => Course(
    id: 'k1',
    diverId: 'd',
    name: 'Rescue',
    agency: 'padi',
    startDate: start ?? DateTime(2026, 3, 1),
    completionDate: completion,
    location: 'Reef',
    notes: 'Calm',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpEditor(WidgetTester tester, Widget editor) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(body: SingleChildScrollView(child: editor)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Enters a date through the picker's text input and confirms it.
  Future<void> enterDateInPicker(WidgetTester tester, DateTime date) async {
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      '$month/$day/${date.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  List<String> agencyOptions(WidgetTester tester) {
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).first,
    );
    // The trailing "Add custom agency..." row is an action (issue #690).
    return [
      for (final item in dropdown.items!)
        if (!item.value!.startsWith('__')) item.value!,
    ];
  }

  testWidgets('Status sets only Status', (tester) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseStatusCardEditor(session: session));

    await tester.enterText(
      find.byKey(const ValueKey('course-edit-name')),
      'Advanced',
    );
    await tester.pump();

    expect(session.changedCardIds, {'status'});
    expect(session.working.name, 'Advanced');
  });

  testWidgets('Mark completed sets the completion date on Details, and the '
      'state reads Completed', (tester) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseStatusCardEditor(session: session));
    expect(find.text('In Progress'), findsOneWidget);

    await tester.tap(find.text('Mark as Completed'));
    await tester.pumpAndSettle();

    // No question: Cancel takes it back.
    expect(find.byType(AlertDialog), findsNothing);
    expect(session.working.completionDate, isNotNull);
    expect(session.changedCardIds, {'details'});
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Mark as Completed'), findsNothing);
  });

  testWidgets('Details sets only Details', (tester) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    await tester.enterText(
      find.byKey(const ValueKey('course-edit-location')),
      'Blue Hole',
    );
    await tester.pump();

    expect(session.changedCardIds, {'details'});
    expect(session.working.location, 'Blue Hole');
  });

  testWidgets('switching completed on shows today\'s date', (tester) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    final completed = session.working.completionDate!;
    final today = DateTime.now();
    expect(
      DateTime(completed.year, completed.month, completed.day),
      DateTime(today.year, today.month, today.day),
    );
    expect(find.text('Completion Date'), findsOneWidget);
  });

  testWidgets('Notes sets only Notes', (tester) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseNotesCardEditor(session: session));

    await tester.enterText(find.byType(TextField), 'Pool day');
    await tester.pump();

    expect(session.changedCardIds, {'notes'});
    expect(session.working.notes, 'Pool day');
  });

  testWidgets('the Details editor offers every agency, including FFESSM', (
    tester,
  ) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    final options = agencyOptions(tester);

    expect(options, contains(CertificationAgency.ffessm.name));
    expect(options, [for (final a in CertificationAgency.values) a.name]);
  });

  testWidgets('the course and certification Details editors offer the same '
      'agencies', (tester) async {
    final courseSession = EditSession(course());
    addTearDown(courseSession.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: courseSession));
    final courseOptions = agencyOptions(tester);

    final certSession = EditSession(
      Certification(
        id: 'c1',
        name: '',
        agency: 'padi',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(certSession.dispose);
    await pumpEditor(
      tester,
      CertificationDetailsCardEditor(session: certSession),
    );

    expect(courseOptions, agencyOptions(tester));
  });

  testWidgets('the start date can be set more than one year ahead', (
    tester,
  ) async {
    final session = EditSession(course());
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    final target = DateTime(DateTime.now().year + 2, 6, 15);
    await tester.tap(find.text('Start Date'));
    await tester.pumpAndSettle();
    await enterDateInPicker(tester, target);

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(session.working.startDate, target);
  });

  testWidgets('the completion date picker opens when the start date is in '
      'the future', (tester) async {
    final session = EditSession(
      course(start: DateTime(DateTime.now().year + 2, 6, 15)),
    );
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completion Date'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('a start after the completion date pulls it along', (
    tester,
  ) async {
    final year = DateTime.now().year;
    final session = EditSession(
      course(start: DateTime(year, 1, 1), completion: DateTime(year, 1, 5)),
    );
    addTearDown(session.dispose);
    await pumpEditor(tester, CourseDetailsCardEditor(session: session));

    await tester.tap(find.text('Start Date'));
    await tester.pumpAndSettle();
    await enterDateInPicker(tester, DateTime(year, 2, 1));

    expect(session.working.completionDate, DateTime(year, 2, 1));
  });
}
