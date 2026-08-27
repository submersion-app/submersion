import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression coverage for the embedded (master-detail) course editor's header
/// Save button. It used to call `_save(null)`, which built the course with an
/// empty id while still taking the update branch, so the write became an
/// `UPDATE ... WHERE id = ''` that matched no rows and failed silently.
void main() {
  late CourseRepository repository;
  late Course seededCourse;

  setUp(() async {
    await setUpTestDatabase();
    repository = CourseRepository();

    // courses.diver_id has a foreign key to divers(id), so a real diver row
    // must exist before a course can be inserted.
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'Test Diver',
        isDefault: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      ),
    );

    seededCourse = await repository.createCourse(
      Course(
        id: '',
        diverId: diver.id,
        name: 'Rescue Diver',
        agency: CertificationAgency.padi,
        startDate: DateTime(2024, 5, 1),
        instructorName: 'Alice Instructor',
        location: 'Blue Hole',
        notes: 'Initial notes',
        createdAt: DateTime(2024, 5, 1),
        updatedAt: DateTime(2024, 5, 1),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Widget buildHarness({
    required List<Override> overrides,
    required String courseId,
    VoidCallback? onSaved,
  }) {
    return ProviderScope(
      overrides: [
        ...overrides,
        courseRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CourseEditPage(
            courseId: courseId,
            embedded: true,
            onSaved: onSaved,
          ),
        ),
      ),
    );
  }

  testWidgets('embedded header Save persists edits to an existing course', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    var savedCalled = false;

    await tester.pumpWidget(
      buildHarness(
        overrides: overrides,
        courseId: seededCourse.id,
        onSaved: () => savedCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    final numberField = find.widgetWithText(TextFormField, 'Instructor Number');
    await tester.ensureVisible(numberField);
    await tester.pumpAndSettle();
    await tester.enterText(numberField, 'INS-4242');
    await tester.pumpAndSettle();

    // The embedded header's Save, not the "Save Changes" button at the bottom
    // of the form.
    final headerSave = find.widgetWithText(TextButton, 'Save');
    expect(headerSave, findsOneWidget);
    await tester.tap(headerSave);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedCalled, isTrue);

    final reloaded = await repository.getCourseById(seededCourse.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.instructorNumber, 'INS-4242');
    // The rest of the course must survive the update untouched.
    expect(reloaded.name, 'Rescue Diver');
    expect(reloaded.location, 'Blue Hole');
  });

  testWidgets(
    'embedded header Save updates the existing course instead of creating one',
    (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(overrides: overrides, courseId: seededCourse.id),
      );
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'Course Name');
      await tester.ensureVisible(nameField);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Rescue Diver (Renamed)');
      await tester.pumpAndSettle();

      final headerSave = find.widgetWithText(TextButton, 'Save');
      await tester.tap(headerSave);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final all = await repository.getAllCourses();
      expect(all, hasLength(1));
      expect(all.single.id, seededCourse.id);
      expect(all.single.name, 'Rescue Diver (Renamed)');
    },
  );
}
